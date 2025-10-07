#!/bin/bash
set -e

# Render patroni.yml with environment variables
envsubst < /etc/patroni.yml > /tmp/patroni.yml

# Start etcd using PATRONI_NAME as identity
etcd \
  --name="${PATRONI_NAME}" \
  --data-dir=/var/lib/etcd \
  --initial-cluster-state=new \
  --initial-cluster-token=pg-drip-etcd \
  --initial-advertise-peer-urls=http://${PATRONI_NAME}:2380 \
  --listen-peer-urls=http://0.0.0.0:2380 \
  --advertise-client-urls=http://${PATRONI_NAME}:2379 \
  --listen-client-urls=http://0.0.0.0:2379 &

# Start PgBouncer
mkdir -p /var/run/pgbouncer
chown postgres:postgres /var/run/pgbouncer
pgbouncer -d /etc/pgbouncer/pgbouncer.ini &

# Start Patroni
exec patroni /tmp/patroni.yml