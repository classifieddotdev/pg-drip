FROM postgres:18

# Install deps: python, pip, patroni
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      python3 python3-pip python3-setuptools python3-wheel \
      curl ca-certificates gettext-base unzip gosu && \
    pip3 install --no-cache-dir --break-system-packages patroni[consul] psycopg2-binary && \
    rm -rf /var/lib/apt/lists/*

# Install Consul
ENV CONSUL_VERSION=1.17.0
RUN curl -L https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_$(dpkg --print-architecture).zip \
    -o consul.zip && \
    unzip consul.zip && \
    mv consul /usr/local/bin/ && \
    rm consul.zip

# Copy configs
COPY patroni.yml /etc/patroni.yml
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Prepare data + runtime dirs
RUN mkdir -p /var/lib/postgresql /var/lib/consul && \
    chown -R postgres:postgres /var/lib/postgresql /var/lib/consul

#  Drop privileges
RUN mkdir -p /var/lib/postgresql/patroni && \
    chown -R postgres:postgres /var/lib/postgresql /var/lib/postgresql/patroni

# Ports:
# - 5432: Postgres
# - 8008: Patroni REST API
# - 8500: Consul HTTP
# - 8300: Consul server RPC
# - 8301/8302: Consul gossip LAN/WAN
EXPOSE 5432 8008 8500 8300 8301 8302

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]