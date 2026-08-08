#!/bin/bash
set -e

# Use ADVERTISE_IP if provided, else fallback to container hostname/IP
if [ -z "$KAMAL_HOST" ]; then
  KAMAL_HOST=$(hostname -i | awk '{print $1}')
fi

# Resolve KAMAL_HOST to an IP. Kamal sets KAMAL_HOST to the literal host string
# from config, which may be a DNS name (e.g. prod1.mesh.xreach.dev). Consul
# -advertise rejects hostnames ("invalid ip address"); Patroni connect_address
# also wants a resolvable IP. Keep the original as PATRONI_NAME for readable
# cluster identity, but use the resolved IP for advertise + connect_address.
if ! echo "$KAMAL_HOST" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$|^[0-9a-fA-F:]+$'; then
  # Prefer IPv4 (CONSUL_JOIN gossip uses IPv4); fall back to whatever resolves.
  RESOLVED=$(getent ahostsv4 "$KAMAL_HOST" 2>/dev/null | awk '{print $1}' | head -1)
  if [ -z "$RESOLVED" ]; then
    RESOLVED=$(getent hosts "$KAMAL_HOST" | awk '{print $1}' | head -1)
  fi
  if [ -z "$RESOLVED" ]; then
    echo "Warning: could not resolve '$KAMAL_HOST' to an IP; using as-is"
    ADVERTISE_IP="$KAMAL_HOST"
  else
    echo "Resolved KAMAL_HOST '$KAMAL_HOST' -> '$RESOLVED'"
    ADVERTISE_IP="$RESOLVED"
  fi
else
  ADVERTISE_IP="$KAMAL_HOST"
fi
export ADVERTISE_IP
export PATRONI_NAME="$KAMAL_HOST"
echo "Using Patroni name: $PATRONI_NAME (advertise IP: $ADVERTISE_IP)"
sleep 3

# Render patroni.yml with environment variables
envsubst < /etc/patroni.yml > /tmp/patroni.yml

# fix consul permissions
chown -R postgres:postgres /var/lib/consul || true
# fix patroni permissions
chown -R postgres:postgres /var/lib/postgresql || true
#chmod 0700 /var/lib/postgresql/patroni

# convenience 
export PATRONI_CONFIG_FILE=/tmp/patroni.yml
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
  -advertise="$ADVERTISE_IP" \
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