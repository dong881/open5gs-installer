#!/bin/bash
set -euo pipefail

# ==========================================
# 0. Configuration Variables
# ==========================================
# Sudo password to execute network configuration commands
PASS="bmwlab"

# Mode of Open5GS: "local" or "external"
# "local": Uses standard loopback (127.0.0.x) for all components. No virtual IP is created on physical link.
# "external": MME, AMF, SGWU, and UPF use physical IP. Automatically creates a virtual IP for gNB link.
MODE="${1:-local}"

if [ "$MODE" != "local" ] && [ "$MODE" != "external" ]; then
  echo "Usage: $0 [local|external]"
  exit 1
fi

# Define Base Directory (dynamically gets the script's directory)
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if Open5GS binaries exist before starting
if [ ! -f "$BASE_DIR/open5gs/build/src/nrf/open5gs-nrfd" ]; then
  echo "❌ Error: Open5GS binaries not found!"
  echo "Please compile Open5GS first by running:"
  echo "  ./install_open5gs.sh"
  exit 1
fi

echo "=== 🚀 Starting Open5GS Core Network Setup (Mode: $MODE) ==="

# Auto-detect interface with default gateway (connected to internet/external gateway)
AUTO_INF=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
if [ -z "$AUTO_INF" ]; then
  AUTO_INF=$(ip -o -4 route show to default | awk '{print $5}' | head -n1 || echo "")
fi
if [ -z "$AUTO_INF" ]; then
  AUTO_INF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | head -n1 || echo "")
fi

# Active Network Interface name (usually reads from the auto-detected interface)
INF="${INF:-$AUTO_INF}"

# Auto-detect primary node IP
AUTO_NODE_IP=$(ip -o -4 addr show dev "$INF" | awk '{print $4}' | cut -d/ -f1 | head -n1 || echo "")

# Local base node IP
NODE_IP="${NODE_IP:-$AUTO_NODE_IP}"

# Virtual IP to bind VNF (defaults to node_ip with last octet incremented by 1)
if [ -z "${VNF_VI_IP:-}" ]; then
  if [ -n "$NODE_IP" ]; then
    BASE_IP=$(echo "$NODE_IP" | cut -d. -f1-3)
    LAST_OCTET=$(echo "$NODE_IP" | cut -d. -f4)
    NEXT_OCTET=$((LAST_OCTET + 1))
    VNF_VI_IP="${BASE_IP}.${NEXT_OCTET}"
  else
    VNF_VI_IP="192.168.8.27"
  fi
fi

TUN_IP="10.45.0.1"

echo "Using network interface: $INF"
echo "Primary node IP:         $NODE_IP"
echo "VNF Virtual IP:          $VNF_VI_IP"
echo "Base Directory:          $BASE_DIR"

# Generate actual config file from template based on MODE
if [ "$MODE" = "external" ]; then
  echo "Generating all_open5gs.yaml config file from EXTERNAL template..."
  sed -e "s|@BASE_DIR@|$BASE_DIR|g" -e "s|@NODE_IP@|$NODE_IP|g" "$BASE_DIR/all_open5gs_external.yaml.template" > "$BASE_DIR/all_open5gs.yaml"
else
  echo "Generating all_open5gs.yaml config file from LOCAL template..."
  sed -e "s|@BASE_DIR@|$BASE_DIR|g" "$BASE_DIR/all_open5gs_local.yaml.template" > "$BASE_DIR/all_open5gs.yaml"
fi

echo "1. Cleaning up old virtual network cards and namespaces"
echo "$PASS" | sudo -S ip link delete ogstun 2>/dev/null || true
echo "$PASS" | sudo -S ip link delete vrf-ogs 2>/dev/null || true
echo "$PASS" | sudo -S ip netns delete core-ns 2>/dev/null || true

if [ "$MODE" = "external" ]; then
  echo "2. Setting up virtual IP on VNF (${VNF_VI_IP}) for gNB"
  if ! ip addr show "${INF}" | grep -q "${VNF_VI_IP}"; then
    echo "$PASS" | sudo -S ip addr add "${VNF_VI_IP}/24" dev "${INF}"
    echo "  > Virtual IP: ${VNF_VI_IP} added to ${INF}"
  else
    echo "  > Virtual IP: ${VNF_VI_IP} already exists"
  fi
else
  echo "2. Skipping virtual IP setup (Local/Loopback mode)"
fi

echo "3. Creating Open5GS TUN virtual interface (ogstun)"
echo "$PASS" | sudo -S ip tuntap add name ogstun mode tun
echo "$PASS" | sudo -S ip addr add "${TUN_IP}/16" dev ogstun
echo "$PASS" | sudo -S ip link set ogstun mtu 1400
echo "$PASS" | sudo -S ip link set ogstun txqueuelen 10000
echo "$PASS" | sudo -S ip link set ogstun up
echo "  > ogstun interface is UP"

echo "4. Setting up iptables NAT forwarding rules"
echo "$PASS" | sudo -S iptables -t nat -D POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null || true
echo "$PASS" | sudo -S iptables -t nat -A POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE
echo "  > NAT forwarding rules configured"

echo "5. Starting Open5GS Network Functions (NFs) in screens..."
mkdir -p "$BASE_DIR/open5gs_logs"
SESSIONS=(nrf scp udr udm ausf pcf bsf nssf amf smf)

for s in "${SESSIONS[@]}"; do
  screen -L -Logfile "$BASE_DIR/open5gs_logs/${s}.log" -S "${s}" -d -m "$BASE_DIR/open5gs/build/src/${s}/open5gs-${s}d" -c "$BASE_DIR/all_open5gs.yaml"
  sleep 0.5
done

# Start UPF (which requires root permission)
echo "$PASS" | sudo -S screen -L -Logfile "$BASE_DIR/open5gs_logs/upf.log" -S upf -d -m bash -lc "sudo $BASE_DIR/open5gs/build/src/upf/open5gs-upfd -c $BASE_DIR/all_open5gs.yaml"

echo "Open5GS NFs started in background screen sessions."

# 6. Start WebUI in screen
echo "6. Starting Open5GS WebUI in screen..."
WEBUI_HOST="127.0.0.1"
if [ "$MODE" = "external" ]; then
  WEBUI_HOST="0.0.0.0"
fi
screen -S webui -d -m bash -lc "export NVM_DIR=\"\$HOME/.nvm\"; [ -s \"\$NVM_DIR/nvm.sh\" ] && \. \"\$NVM_DIR/nvm.sh\"; nvm use 16.20.2; cd \"$BASE_DIR/open5gs/webui\"; HOSTNAME=$WEBUI_HOST npm run dev"

echo "=== ✅ Open5GS Core Startup Finished ==="
