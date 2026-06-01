#!/bin/bash
set -euo pipefail

# Define Base Directory
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Validate Mode Argument
MODE="${1:-local}"
if [ "$MODE" != "local" ] && [ "$MODE" != "external" ]; then
  echo "❌ Error: Invalid mode '$MODE'."
  echo "Usage: $0 [local|external] [cpu_list]"
  exit 1
fi

echo "=========================================="
echo "      🔄 Restarting Open5GS Core Network"
echo "=========================================="
echo ""

# Execute stop script
"$BASE_DIR/stop_open5gs.sh" "$@"

echo ""
echo "Waiting 2 seconds to release network ports and resources..."
sleep 2
echo ""

# Execute start script
"$BASE_DIR/start_open5gs_core.sh" "$@"
