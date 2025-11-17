#!/bin/bash
set -e

# fallback: if no PATRONI_NAME set, use hostname
if [ -z "$PATRONI_NAME" ]; then
  export PATRONI_NAME="$HOSTNAME"
fi

# Use ADVERTISE_IP if provided, else fallback to container hostname/IP
if [ -z "$KAMAL_HOST" ]; then
  KAMAL_HOST=$(hostname -i | awk '{print $1}')
fi

# Render patroni.yml with environment variables
envsubst < /etc/patroni.yml > /tmp/patroni.yml

# fix consul permissions
chown -R postgres:postgres /var/lib/consul || true
# fix patroni permissions
#chown -R postgres:postgres /var/lib/postgresql/patroni || true
#chmod 0700 /var/lib/postgresql/patroni

# convenience 
export PATRONI_CONFIG_FILE=/etc/patroni.yml
export PATRONI_SCOPE=pg-drip

# Default values
CONSUL_EXPECT=${CONSUL_EXPECT:-3}
CONSUL_JOIN=${CONSUL_JOIN:-""}

# Build retry-join args dynamically
JOIN_ARGS=""
if [ -n "$CONSUL_JOIN" ]; then
  IFS=',' read -ra HOSTS <<< "$CONSUL_JOIN"
  for h in "${HOSTS[@]}"; do
    JOIN_ARGS="$JOIN_ARGS -retry-join=$h"
  done
fi

echo "Starting Consul with bootstrap-expect=$CONSUL_EXPECT $JOIN_ARGS"

# Start Consul agent (backgrounded)
gosu postgres consul agent \
  -server \
  -bootstrap-expect=$CONSUL_EXPECT \
  -node="${PATRONI_NAME}" \
  -data-dir=/var/lib/consul \
  -bind=0.0.0.0 \
  -client=0.0.0.0 \
  -advertise="$KAMAL_HOST" \
  $JOIN_ARGS \
  -ui &

# Wait for Consul HTTP to respond before Patroni starts
echo "Waiting for Consul to become available..."
for i in {1..20}; do
  if curl -s http://127.0.0.1:8500/v1/status/leader | grep -q '"'; then
    echo "Consul is ready"
    break
  fi
  echo "Consul not ready yet... ($i)"
  sleep 2
done

# Start Patroni
exec gosu postgres patroni /tmp/patroni.yml