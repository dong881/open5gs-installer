# Open5GS Portable Installer & Control Scripts

This repository contains fully automated, portable, and location-independent scripts to install, run, stop, and restart Open5GS on Ubuntu, pre-seeding MongoDB with default subscriber and administration configurations.

## Features

1. **One-Click Seeding**: Automatically populates MongoDB with **42 subscribers** and the default `admin` WebUI user account using native BSON ObjectIDs and NumberLong values on a fresh MongoDB 8.0 installation.
2. **Dynamic Network Detection**: Automatically identifies the active network interface connected to the default gateway (internet) to setup virtual IP mappings and NAT rules dynamically.
3. **Location Independence**: Avoids hardcoded usernames or absolute directories (like `/home/hpe`). Scripts run relative to their installation path (`BASE_DIR`).
4. **Parameterization**: Key parameters (sudo passwords, network interface overrides, VNF virtual IP ranges) are clearly parameterized at the top of the scripts.

---

## File Overview

- `install_open5gs.sh`: Installs system dependencies, installs MongoDB 8.0, and seeds it with default subscriber/account data. Finally builds Open5GS from source.
- `start_open5gs_core.sh`: Configures network interfaces, creates the `ogstun` card, sets up IP forwarding/NAT rules, compiles `all_open5gs.yaml` dynamically from the template, and runs all Open5GS NFs in background `screen` sessions.
- `stop_open5gs.sh`: Shuts down screen sessions and cleans up NAT rules, the `ogstun` card, virtual IPs, and network namespace allocations.
- `restart_open5gs.sh`: Standard wrapper to restart Open5GS core network.
- `stop_network_oai5g.sh`: Standard wrapper that links directly to the stop script.
- `all_open5gs.yaml.template`: Template configuration for Open5GS with `@BASE_DIR@` and `@NODE_IP@` placeholders.

---

## Getting Started

### 1. Installation

To install Open5GS and seed the database, run:
```bash
chmod +x *.sh
./install_open5gs.sh
```

### 2. Startup

To configure virtual IPs, network routing, NAT, and start NFs in screen sessions:
```bash
./start_open5gs_core.sh
```
To view running components:
```bash
screen -ls
```

To attach to a specific component log (e.g., AMF):
```bash
screen -r amf
# Press Ctrl + A followed by D to detach
```

### 3. Stop / Clean Network

To stop all components and reset network interface bindings:
```bash
./stop_network_oai5g.sh
```

### 4. Restart Core Network

To clean the interfaces and restart all services:
```bash
./restart_open5gs.sh
```
