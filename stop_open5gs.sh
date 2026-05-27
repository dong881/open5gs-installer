#!/bin/bash
set -euo pipefail

# ==========================================
# 0. Configuration Variables
# ==========================================
# Sudo password to execute network configuration commands
PASS="bmwlab"

# Prompt for sudo password if the default one is incorrect
if ! echo "$PASS" | sudo -S true 2>/dev/null; then
  if [ -t 0 ]; then
    read -rs -p "[sudo] password for $USER: " PASS
    echo ""
  else
    echo "❌ Error: sudo authentication failed and terminal is non-interactive."
    exit 1
  fi
fi

# Define Base Directory
BASE_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "=== 🛑 Stopping Open5GS Core Network ==="

# Auto-detect interface with default gateway (connected to internet/external gateway)
AUTO_INF=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
if [ -z "$AUTO_INF" ]; then
  AUTO_INF=$(ip -o -4 route show to default | awk '{print $5}' | head -n1 || echo "")
fi
if [ -z "$AUTO_INF" ]; then
  AUTO_INF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v 'lo' | head -n1 || echo "")
fi

INF="${INF:-$AUTO_INF}"

# Auto-detect primary node IP
AUTO_NODE_IP=$(ip -o -4 addr show dev "$INF" | awk '{print $4}' | cut -d/ -f1 | head -n1 || echo "")
NODE_IP="${NODE_IP:-$AUTO_NODE_IP}"

# Virtual IP to bind VNF (defaults to node_ip with last octet incremented by 1)
if [ -z "${VNF_VI_IP:-}" ]; then
  if [ -n "$NODE_IP" ]; then
    BASE_IP=$(echo "$NODE_IP" | cut -d. -f1-3)
    LAST_OCTET=$(echo "$NODE_IP" | cut -d. -f4)
    NEXT_OCTET=$((LAST_OCTET + 1))
    VNF_VI_IP="${BASE_IP}.${NEXT_OCTET}"
  else
    VNF_VI_IP="192.168.1.200"
  fi
fi

echo "=== 🛑 1. Stopping Open5GS and WebUI processes ==="
echo "$PASS" | sudo -S pkill '^open5gs-' 2>/dev/null || true
echo "$PASS" | sudo -S pkill -f 'screen.*open5gs' 2>/dev/null || true
echo "$PASS" | sudo -S pkill -f 'npm run dev' 2>/dev/null || true
echo "$PASS" | sudo -S pkill -f 'node.*webui' 2>/dev/null || true

screen -X -S webui quit 2>/dev/null || true
for s in nrf scp udr udm ausf pcf bsf nssf amf smf upf; do
  screen -X -S "${s}" quit 2>/dev/null || true
done

echo "  > Open5GS and WebUI processes shut down"

echo "=== 🧹 2. Cleaning up virtual network cards & routing ==="
echo "  > Removing NAT forwarding rules..."
echo "$PASS" | sudo -S iptables -t nat -D POSTROUTING -s 10.45.0.0/16 ! -o ogstun -j MASQUERADE 2>/dev/null || true

echo "  > Deleting ogstun virtual card..."
echo "$PASS" | sudo -S ip link delete ogstun 2>/dev/null || true
echo "$PASS" | sudo -S ip link delete vrf-ogs 2>/dev/null || true
echo "$PASS" | sudo -S ip netns delete core-ns 2>/dev/null || true

if [ -n "$VNF_VI_IP" ] && [ -n "$INF" ]; then
  if ip addr show "${INF}" | grep -q "${VNF_VI_IP}"; then
    echo "  > Removing virtual IP ${VNF_VI_IP} from ${INF}..."
    echo "$PASS" | sudo -S ip addr del "${VNF_VI_IP}/24" dev "${INF}" 2>/dev/null || true
  fi
fi

echo "=== ✅ Open5GS Core Network fully cleaned up ==="
