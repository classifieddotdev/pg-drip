#!/bin/bash
set -e

# Render patroni.yml with environment variables
envsubst < /etc/patroni.yml > /tmp/patroni.yml

# fix patroni perms 
chown -R postgres:postgres /var/lib/postgresql/patroni
chmod 0700 /var/lib/postgresql/patroni

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
consul agent \
  -server \
  -bootstrap-expect=$CONSUL_EXPECT \
  -node="${PATRONI_NAME}" \
  -data-dir=/var/lib/consul \
  -bind=0.0.0.0 \
  -client=0.0.0.0 \
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
exec patroni /tmp/patroni.yml