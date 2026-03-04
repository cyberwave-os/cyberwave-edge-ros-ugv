#!/bin/sh
set -e

# Cyberwave Driver Entrypoint
#
# Bridges the standard Cyberwave driver interface to the ROS 2 UGV stack.
# The edge core passes:
#   CYBERWAVE_API_KEY          - API token for authentication
#   CYBERWAVE_TWIN_UUID        - UUID of the twin this driver controls
#   CYBERWAVE_TWIN_JSON_FILE   - Path to JSON file with full twin + asset data
#
# This entrypoint:
#   1. Reads the twin JSON file and exports metadata as CYBERWAVE_METADATA_* env vars
#   2. Maps CYBERWAVE_API_KEY → CYBERWAVE_TOKEN (what the ROS bridge expects)
#   3. Forwards CYBERWAVE_MQTT_HOST, CYBERWAVE_ENVIRONMENT, etc.
#   4. Starts SSH (for remote debug access)
#   5. Exec's the CMD (start_ugv.sh or whatever is passed)

# --- Expand twin JSON file into env vars (same pattern as camera driver) ---
if [ -n "$CYBERWAVE_TWIN_JSON_FILE" ] && [ -f "$CYBERWAVE_TWIN_JSON_FILE" ]; then
    echo "[entrypoint] Reading twin config from $CYBERWAVE_TWIN_JSON_FILE"
    eval "$(python3 -c "
import json, os, re, shlex

with open(os.environ['CYBERWAVE_TWIN_JSON_FILE']) as f:
    data = json.load(f)

_VALID_ENV_NAME = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')

def export_vars(data, prefix='CYBERWAVE'):
    for key, value in data.items():
        if prefix == 'CYBERWAVE' and key == 'uuid':
            env_name = 'CYBERWAVE_TWIN_UUID'
        else:
            env_name = prefix + '_' + key.upper()
        if not _VALID_ENV_NAME.match(env_name):
            continue
        if env_name in os.environ:
            continue
        if isinstance(value, dict):
            export_vars(value, env_name)
        elif isinstance(value, list):
            print(f'export {env_name}={shlex.quote(json.dumps(value))}')
        else:
            print(f'export {env_name}={shlex.quote(str(value))}')

export_vars(data)
")"
fi

# --- Map CYBERWAVE_API_KEY to CYBERWAVE_TOKEN (bridge node reads CYBERWAVE_TOKEN) ---
if [ -n "$CYBERWAVE_API_KEY" ] && [ -z "$CYBERWAVE_TOKEN" ]; then
    export CYBERWAVE_TOKEN="$CYBERWAVE_API_KEY"
fi

# --- Start SSH for remote debug access ---
service ssh start 2>/dev/null || true

echo "[entrypoint] CYBERWAVE_TWIN_UUID=${CYBERWAVE_TWIN_UUID:-<not set>}"
echo "[entrypoint] CYBERWAVE_TOKEN=${CYBERWAVE_TOKEN:+<set>}${CYBERWAVE_TOKEN:-<not set>}"
echo "[entrypoint] CYBERWAVE_MQTT_HOST=${CYBERWAVE_MQTT_HOST:-<not set>}"
echo "[entrypoint] CYBERWAVE_ENVIRONMENT=${CYBERWAVE_ENVIRONMENT:-<not set>}"

exec "$@"
