#!/usr/bin/env bash
# cleanup_recover.sh
#
# Removes retained Home Assistant MQTT discovery topics.
# Useful when discovery payloads or entity IDs change.
#
# Usage:
#   export MQTT_HOST=...
#   export MQTT_USER=...
#   export MQTT_PASS=...
#   ./cleanup_recover.sh

set -euo pipefail

# ====== CONFIG (override via env) ======
MQTT_HOST="${MQTT_HOST:-}"
MQTT_PORT="${MQTT_PORT:-}"
MQTT_USER="${MQTT_USER:-}"
MQTT_PASS="${MQTT_PASS:-}"
HA_DISCOVERY_PREFIX="${HA_DISCOVERY_PREFIX:-homeassistant}"

if [[ -z "$MQTT_PASS" ]]; then
  echo "ERROR: MQTT_PASS is empty. Export it first."
  echo "Example:"
  echo "  export MQTT_PASS='xxx'"
  exit 1
fi

echo "MQTT_HOST=$MQTT_HOST"
echo "HA_DISCOVERY_PREFIX=$HA_DISCOVERY_PREFIX"
echo

tmp="/tmp/mediola_discovery_topics.txt"
rm -f "$tmp"

echo "Collecting retained discovery topics for mediola (10s window)..."

# IMPORTANT: --retained-only fetches retained topics; WITHOUT -R
timeout 10s mosquitto_sub \
  -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
  -t "${HA_DISCOVERY_PREFIX}/#" -v --retained-only \
| awk '{print $1}' \
| grep -E "^${HA_DISCOVERY_PREFIX}/(cover|button)/(ER_|mediola_ER_|rf_|rl_).*?/config$" \
| sort -u \
> "$tmp" || true

count=$(wc -l < "$tmp" | tr -d ' ')
echo "Found $count retained topics to delete."

if [[ "$count" -eq 0 ]]; then
  echo "Nothing to delete."
  exit 0
fi

echo
echo "About to DELETE retained topics listed in: $tmp"
echo "Proceed? Type 'yes' to continue:"
read -r ans
if [[ "$ans" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

while read -r t; do
  [[ -z "$t" ]] && continue
  echo "Clearing $t"
  mosquitto_pub -h "$MQTT_HOST" -p "$MQTT_PORT" -u "$MQTT_USER" -P "$MQTT_PASS" \
    -t "$t" -r -n
done < "$tmp"

echo
echo "Done. Now restart Home Assistant, then restart the mediola2mqtt bridge."