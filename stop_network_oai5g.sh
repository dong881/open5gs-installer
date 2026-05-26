#!/bin/bash
set -euo pipefail

# Define Base Directory
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Execute standard stop script
"$BASE_DIR/stop_open5gs.sh"
