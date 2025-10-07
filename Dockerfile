FROM postgres:18

# Install deps: python, pip, patroni, PgBouncer
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip python3-setuptools python3-wheel \
      curl ca-certificates pgbouncer gettext-base && \
    pip3 install --no-cache-dir --break-system-packages patroni[etcd] psycopg2-binary && \
    rm -rf /var/lib/apt/lists/*

# Install etcd (multi-arch safe)
ARG TARGETARCH
ENV ETCD_VER=v3.5.16
RUN case "${TARGETARCH}" in \
      amd64) ARCH=amd64 ;; \
      arm64) ARCH=arm64 ;; \
      *) echo "unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-${ARCH}.tar.gz \
    | tar xz -C /tmp && \
    cp /tmp/etcd-${ETCD_VER}-linux-${ARCH}/etcd /usr/local/bin/ && \
    cp /tmp/etcd-${ETCD_VER}-linux-${ARCH}/etcdctl /usr/local/bin/ && \
    rm -rf /tmp/etcd-${ETCD_VER}-linux-${ARCH}

# Copy configs
COPY patroni.yml /etc/patroni.yml
COPY pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY userlist.txt /etc/pgbouncer/userlist.txt
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

# Prepare data + runtime dirs
RUN mkdir -p /var/lib/postgresql /var/lib/etcd /var/run/pgbouncer && \
    chown -R postgres:postgres /var/lib/postgresql /var/lib/etcd /var/run/pgbouncer

#  Drop privileges
RUN mkdir -p /var/lib/postgresql/patroni && \
    chown -R postgres:postgres /var/lib/postgresql

USER postgres

# Volumes for persistence
VOLUME ["/var/lib/postgresql/patroni", "/var/lib/etcd"]

# Ports:
# - 5432: Postgres
# - 6432: PgBouncer
# - 8008: Patroni REST API
# - 2379: etcd client
# - 2380: etcd peer
EXPOSE 5432 6432 8008 2379 2380

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]