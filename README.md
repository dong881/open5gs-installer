# Open5GS Portable Installer & Control Scripts

This repository contains fully automated, portable, and location-independent scripts to install, run, stop, and restart Open5GS on Ubuntu, pre-seeding MongoDB with default subscriber and administration configurations.

## Features

1. **Local & External Modes**:
   - **`local` Mode** (Default): Uses standard loopback (`127.0.0.x`) for all control interface bindings. **Does not require creating a Virtual IP** on the physical interface. Perfect for single-machine operations and testing.
   - **`external` Mode**: Configures AMF, UPF, MME, and SGWU to bind to the machine's physical IP and **automatically creates an additional Virtual IP** on the interface for gNB connectivity.
2. **One-Click Seeding**: Automatically populates MongoDB with **42 subscribers** and the default `admin` WebUI user account using native BSON ObjectIDs and NumberLong values on a fresh MongoDB 8.0 installation.
3. **Dynamic Network Detection**: Automatically identifies the active network interface connected to the default gateway (internet) to setup virtual IP mappings and NAT rules dynamically.
4. **Automated WebUI Setup**: Automatically installs Node.js `v16.20.2` via NVM and installs the WebUI dependencies during installation. Starts the WebUI inside a detached screen session (`webui`) automatically.

---

## Configuration

You can select the network mode directly by passing it as a command-line argument when starting the core network:
- **Local Mode** (Loopback bindings, no virtual IP needed):
  ```bash
  ./start_open5gs_core.sh local
  ```
- **External Mode** (Physical binding + Virtual IP setup for gNB):
  ```bash
  ./start_open5gs_core.sh external
  ```

---

## File Overview

- `install_open5gs.sh`: Installs system dependencies, installs MongoDB 8.0, seeds the DB, installs NVM + Node.js v16.20.2, builds Open5GS from source, and pulls/installs WebUI dependencies.
- `start_open5gs_core.sh`: Configures network interfaces, creates `ogstun`, configures NAT forwarding rules, compiles configuration templates, starts Open5GS services, and launches the WebUI in a screen session.
- `stop_open5gs.sh`: Shuts down screen sessions (including `webui`) and cleans up NAT rules, the `ogstun` card, virtual IPs, and network namespace allocations.
- `restart_open5gs.sh`: Standard wrapper to restart Open5GS core network.
- `stop_network_oai5g.sh`: Standard wrapper that links directly to the stop script.
- `all_open5gs_local.yaml.template`: Loopback config template.
- `all_open5gs_external.yaml.template`: Physical IP config template.

---

## Getting Started

### 1. Installation

To install Open5GS, build the WebUI, and seed the database:
```bash
chmod +x *.sh
./install_open5gs.sh
```

### 2. Startup

To launch the core network services and the WebUI in local loopback mode (default):
```bash
./start_open5gs_core.sh
```

To launch in external IP mode (which configures the physical IP and creates the Virtual IP):
```bash
./start_open5gs_core.sh external
```
To view running screen components:
```bash
screen -ls
```

To attach to a specific component log (e.g., AMF):
```bash
screen -r amf
# Press Ctrl + A followed by D to detach
```

To attach to the WebUI log:
```bash
screen -r webui
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
