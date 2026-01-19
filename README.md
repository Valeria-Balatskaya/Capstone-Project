# LoRa Indoor Positioning System

A distributed RSSI/SNR log collection system for indoor positioning research using LoRa technology. Collects signal strength data from multiple receivers and calculates tag position via trilateration.

## Overview

```
                              ┌─────────────────────────────┐
                              │       CENTRAL SERVER        │
                              │  ┌───────────┐ ┌──────────┐ │
                              │  │ Receiver  │ │WebSocket │ │
                              │  │  A (opt)  │ │Server    │ │
                              │  └─────┬─────┘ └────┬─────┘ │
                              │        │USB         │:8765  │
                              └────────┼────────────┼───────┘
                                       │            │
    ┌──────────────────────────────────┼────────────┼──────────────────────────────────┐
    │                                  │            │                                  │
    ▼                                  ▼            ▼                                  ▼
┌────────────┐                  ┌────────────┐ ┌────────────┐                  ┌────────────┐
│  RECEIVER  │                  │  RECEIVER  │ │  RECEIVER  │                  │    TAG     │
│     B      │                  │     C      │ │     ...    │                  │  (Mobile)  │
│            │                  │            │ │            │                  │            │
│  Streams   │──── WebSocket ──▶│  Streams   │ │  Streams   │                  │ Broadcasts │
│  RSSI/SNR  │                  │  RSSI/SNR  │ │  RSSI/SNR  │                  │   LoRa     │
└────────────┘                  └────────────┘ └────────────┘                  └────────────┘
      ▲                               ▲              ▲                               │
      │                               │              │                               │
      └───────────────────────────────┴──────────────┴───────────────────────────────┘
                                    LoRa Signal (868 MHz)
```

**Data Flow:**
1. Mobile **TAG** broadcasts LoRa packets
2. Multiple **RECEIVERS** (A, B, C, ...) capture packets with RSSI/SNR
3. Remote receivers stream data via **WebSocket** to central server
4. Server aggregates all data to CSV
5. **Trilateration** calculates tag position from RSSI values

---

## Hardware Requirements

### LoRa Boards
- **Wio-E5 Development Kit** (Seeed Studio) — recommended
- Any STM32WL-based board with AT command firmware
- **Minimum: 4 boards** = 1 tag + 3 receivers (A, B, C)
- More receivers = better positioning accuracy

### Computers
- **Minimum: 4 computers** (laptops, desktops, or Raspberry Pis)
  - 1 for central server (runs `server.py` + receiver A)
  - 1 for mobile tag (runs `tag.py` - walk around with this!)
  - 1 for receiver B (runs `receiver_B.py`)
  - 1 for receiver C (runs `receiver_C.py`)
- Any combination of Windows, macOS, or Linux
- All machines must be on the same network

### Antennas
- 868 MHz antennas (EU) or 915 MHz (US)
- Antenna orientation affects signal strength significantly

---

## Firmware

### Custom Firmware (Included)

The file `FreeRTOS_LoRaWAN_AT.hex` contains custom firmware for Wio-E5 boards with:
- AT command interface for radio configuration
- Test mode for continuous TX/RX
- RSSI and SNR reporting

### Flashing Firmware

**Prerequisites:**
- [STM32CubeProgrammer](https://www.st.com/en/development-tools/stm32cubeprog.html) (free from ST)

**Steps:**

1. **Connect board via USB** and put in DFU/bootloader mode:
   - Hold BOOT button while pressing RESET
   - Or: Hold BOOT, plug USB, release BOOT

2. **Open STM32CubeProgrammer:**
   - Select connection type: **USB**
   - Click **Connect**

3. **Erase chip (optional but recommended):**
   - Go to "Erasing & Programming" tab
   - Click **Full chip erase**

4. **Flash firmware:**
   - Browse to `FreeRTOS_LoRaWAN_AT.hex`
   - Check "Verify programming"
   - Click **Start Programming**

5. **Reset board:**
   - Press RESET button or power cycle
   - Board should respond to AT commands

**Verify firmware:**
```bash
# Connect via serial terminal (115200 baud)
# Send: AT
# Response: +AT: OK
```

---

## Software Installation

### Python Dependencies

```bash
pip install pyserial websockets
```

Or use requirements.txt:
```bash
pip install -r requirements.txt
```

### Project Files

| File | Purpose | Key Flags |
|------|---------|----------|
| `server.py` | Central server + optional local receiver A | `--port`, `--ws-port`, `--demo` |
| `tag.py` | Mobile tag transmitter | `--port`, `--packets`, `--interval` |
| `receiver_B.py` | Remote receiver B (WebSocket client) | `--port`, `--server`, `--demo` |
| `receiver_C.py` | Remote receiver C (WebSocket client) | `--port`, `--server`, `--demo` |
| `trilateration.py` | Position calculation from RSSI data | `--input`, `--live`, `--calibrate` |
| `position_dashboard.html` | Web-based visualization | N/A |

---

## Command-Line Reference

### server.py - Central Server

Runs the WebSocket server and optionally reads from a local LoRa receiver.

```bash
python server.py [OPTIONS]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--port` | No* | None | Serial port for local receiver A (e.g., `COM5`, `/dev/ttyUSB0`) |
| `--ws-port` | No | 8765 | WebSocket server port |
| `--output` | No | `all_receivers.csv` | Output CSV file path |
| `--demo` | No | False | Demo mode - generates fake data (no hardware) |
| `--list-ports` | No | False | List available serial ports and exit |

*Either `--port` or `--demo` is required.

**Examples:**
```bash
# With local receiver
python server.py --port COM5

# Custom WebSocket port and output file
python server.py --port COM5 --ws-port 9000 --output data.csv

# Demo mode (no hardware)
python server.py --demo

# List available ports
python server.py --list-ports
```

---

### tag.py - Mobile Tag (Transmitter)

Transmits LoRa packets periodically. Walk around with this device.

```bash
python tag.py [OPTIONS]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--port` | Yes | None | Serial port for tag (e.g., `COM3`, `/dev/ttyUSB0`) |
| `--packets` | No | 10 | Number of packets per burst |
| `--interval` | No | 7.0 | Seconds between bursts |
| `--list-ports` | No | False | List available serial ports and exit |

**Examples:**
```bash
# Basic usage
python tag.py --port COM3

# Faster transmissions (5 packets every 3 seconds)
python tag.py --port COM3 --packets 5 --interval 3

# List available ports
python tag.py --list-ports
```

**Behavior:**
- Sends `--packets` packets in quick succession
- Waits `--interval` seconds
- Repeats until Ctrl+C

---

### receiver_B.py / receiver_C.py - Remote Receivers

Receives LoRa packets and streams RSSI/SNR to central server via WebSocket.

```bash
python receiver_B.py [OPTIONS]
python receiver_C.py [OPTIONS]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--port` | No* | None | Serial port for receiver (e.g., `COM5`) |
| `--server` | Yes | None | WebSocket server URL (e.g., `ws://192.168.1.100:8765/data`) |
| `--demo` | No | False | Demo mode - generates fake RSSI data |
| `--list-ports` | No | False | List available serial ports and exit |

*Either `--port` or `--demo` is required.

**Examples:**
```bash
# Basic usage
python receiver_B.py --port COM5 --server ws://192.168.1.100:8765/data

# Demo mode (testing without hardware)
python receiver_B.py --demo --server ws://192.168.1.100:8765/data

# List available ports
python receiver_B.py --list-ports
```

**Important:** The `--server` URL must include:
- Protocol: `ws://` (not `http://` or `https://`)
- Server IP or hostname
- Port: `:8765` (or your custom port)
- Path: `/data` (required!)

---

### trilateration.py - Position Calculator

Calculates tag position from RSSI readings using trilateration.

```bash
python trilateration.py [OPTIONS]
```

| Flag | Required | Default | Description |
|------|----------|---------|-------------|
| `--input`, `-i` | Yes* | None | Input CSV file (from server.py) |
| `--live`, `-l` | No | False | Live mode - continuously watch file for new data |
| `--calibrate`, `-c` | No | False | Run calibration mode |
| `--count` | No | 100 | Number of readings to collect in calibration |
| `--receiver` | No | All | Calibrate specific receiver only (`A`, `B`, or `C`) |
| `--rssi-1m` | No | -45 | Override RSSI at 1 meter value |
| `--path-loss`, `-n` | No | 2.5 | Override path loss exponent |

*Required except when using `--calibrate` without `--input`.

**Examples:**
```bash
# One-time position calculation
python trilateration.py --input all_receivers.csv

# Live tracking (real-time updates)
python trilateration.py --input all_receivers.csv --live

# Show calibration help and RSSI→distance table
python trilateration.py --calibrate

# Automatic calibration (collects 100 readings, calculates median)
python trilateration.py --calibrate --input all_receivers.csv

# Calibrate with custom count
python trilateration.py --calibrate --input all_receivers.csv --count 50

# Calibrate specific receiver only
python trilateration.py --calibrate --input all_receivers.csv --receiver A

# Override calibration values for testing
python trilateration.py --input all_receivers.csv --live --rssi-1m -50 --path-loss 3.0
```

---

## Serial Port Reference

### Finding Your Port

**Windows:**
```powershell
# PowerShell
Get-WMIObject Win32_SerialPort | Select DeviceID, Description

# Or use Device Manager → Ports (COM & LPT)
# Typical: COM3, COM5, COM7
```

**macOS:**
```bash
ls /dev/cu.usbserial-*
# Typical: /dev/cu.usbserial-1110, /dev/cu.usbserial-1120
```

**Linux:**
```bash
ls /dev/ttyUSB* /dev/ttyACM*
# Typical: /dev/ttyUSB0, /dev/ttyACM0
```

### Serial Configuration
- **Baud rate:** 115200
- **Data bits:** 8
- **Stop bits:** 1
- **Parity:** None
- **Line ending:** `\r\n` (for AT commands)

---

## LoRa Radio Configuration

All boards must use **identical radio settings**.

### AT Command Format
```
AT+TCONF=<freq>:<power>:<bandwidth>:<sf>:<cr>:<lna>:<pa>:<crc>:<preamble>:<payload>:<implicit>:<iq>
```

### Default Configuration
```
AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0
```

| Parameter | Value | Description |
|-----------|-------|-------------|
| Frequency | 868300000 | 868.3 MHz (EU band) |
| TX Power | 14 | 14 dBm |
| Bandwidth | 0 | 125 kHz |
| Spreading Factor | 7 | SF7 (fastest) |
| Coding Rate | 4/5 | 4/5 redundancy |
| LNA | 1 | Low-noise amp on |
| PA | 1 | Power amp on |
| CRC | 1 | CRC enabled |
| Preamble | 16 | 16 symbols |
| Payload | 0 | Variable length |
| Implicit Header | 0 | Explicit header |
| IQ Invert | 0 | Normal |

### Key AT Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `ATZ` | Reset board | `ATZ` |
| `AT+TCONF=...` | Configure radio | See above |
| `AT+TRX=N` | Receive N packets | `AT+TRX=9999` (continuous) |
| `AT+TTX=N` | Transmit N packets | `AT+TTX=10` |

---

## Quick Start

> **Hardware Setup:** You need **4 computers** and **4 LoRa boards** for full trilateration. Each computer connects to one LoRa board via USB. See [Hardware Requirements](#hardware-requirements) for details.

### 1. Find Server IP Address

**Windows:**
```powershell
ipconfig | Select-String "IPv4"
```

**macOS/Linux:**
```bash
ifconfig | grep "inet "
# Or: ip addr show | grep "inet "
```

Note your server IP (e.g., `192.168.1.100`).

### 2. Find Serial Ports

Before running with hardware, identify your serial ports:

```bash
# List all available ports
python server.py --list-ports
# Or: python tag.py --list-ports
# Or: python receiver_B.py --list-ports
```

See [Serial Port Reference](#serial-port-reference) section for platform-specific commands.

### 3. Start Central Server

```bash
# With local receiver on server machine (requires --port)
python server.py --port /dev/cu.usbserial-1110  # macOS
python server.py --port COM5                     # Windows
python server.py --port /dev/ttyUSB0             # Linux

# Demo mode (no hardware needed)
python server.py --demo
```

### 4. Start Remote Receivers

On each receiver machine:
```bash
# Receiver B (requires --port and --server)
python receiver_B.py --port COM5 --server ws://SERVER_IP:8765/data

# Receiver C  
python receiver_C.py --port COM7 --server ws://SERVER_IP:8765/data
```

Replace `SERVER_IP` with the IP from step 1.

### 5. Start Mobile Tag

On tag machine (walk around with this!):
```bash
# Requires --port
python tag.py --port COM3
```

At this point, the server is collecting data from all 3 receivers (A, B, C) and saving to `all_receivers.csv`.

### 6. Run Trilateration (Position Calculation)

**Open a NEW terminal on the server machine** and run:
```bash
python trilateration.py --input all_receivers.csv --live
```

This reads the CSV file in real-time and calculates the tag's (X, Y) position from the 3 RSSI values.

**Output:**
```
Position: (1.52, 1.48) m | RSSI: A=-45dBm B=-52dBm C=-48dBm | Dist: A=1.2m B=2.1m C=1.8m
Position: (1.55, 1.50) m | RSSI: A=-43dBm B=-53dBm C=-46dBm | Dist: A=1.1m B=2.2m C=1.7m
```

**Important:** 
- Run trilateration **AFTER** step 3-5 are running
- Keep server.py running (it writes the CSV)
- Keep receivers and tag running (they provide data)
- Trilateration reads and processes in real-time

### 7. View Dashboard (Optional)

Open `position_dashboard.html` in browser, or:
```bash
# Start simple HTTP server
python -m http.server 8000
# Open http://localhost:8000/position_dashboard.html
```

---

## Trilateration & Calibration

### RSSI-to-Distance Model
```
distance = 10^((RSSI_1m - RSSI) / (10 * n))
```

| Parameter | Description | Typical Value |
|-----------|-------------|---------------|
| `RSSI_1m` | Signal strength at 1 meter | -15 to -25 dBm |
| `n` | Path-loss exponent | 2.0–2.5 (open), 3.0–4.5 (walls) |

### Calibration Process

**⚠️ CRITICAL: Trilateration accuracy depends entirely on correct calibration!**

The positioning algorithm uses two key parameters that **MUST be calibrated** for your specific environment:

1. **`RSSI_AT_1M`** - Signal strength at exactly 1 meter
2. **`PATH_LOSS_N`** - Environment-specific signal decay rate

**Without proper calibration, positions will be completely wrong!**

#### Automatic Calibration (Recommended)

The trilateration script includes an **automatic calibration mode** that:
- Collects 100 readings (configurable)
- Calculates median RSSI for each receiver
- Shows statistics (mean, range, standard deviation)
- Outputs ready-to-copy configuration

**Step 1: Setup for Calibration**

1. Place tag **exactly 1 meter** from receiver(s):
   - Use a measuring tape for accuracy
   - Ensure direct line-of-sight (no obstacles between tag and receiver)
   
2. Start server and tag:
   ```bash
   # Terminal 1: Start server
   python server.py --port <PORT>
   
   # Terminal 2: Start tag (on separate machine)
   python tag.py --port <PORT>
   ```

**Step 2: Run Automatic Calibration**

```bash
# Terminal 3: Run calibration
python trilateration.py --calibrate --input all_receivers.csv
```

**Output:**
```
======================================================================
AUTOMATIC CALIBRATION - COLLECTING READINGS
======================================================================
Target: 100 readings per receiver
======================================================================

Collecting data.......... Done!

======================================================================
CALIBRATION RESULTS
======================================================================

Receiver A (100 readings):
  Median RSSI: -48.0 dBm  ← USE THIS VALUE
  Mean RSSI:   -48.3 dBm
  Range:       -52.0 to -45.0 dBm
  Std Dev:     1.82 dB

Receiver B (100 readings):
  Median RSSI: -47.0 dBm  ← USE THIS VALUE
  Mean RSSI:   -47.1 dBm
  Range:       -50.0 to -44.0 dBm
  Std Dev:     1.54 dB

Receiver C (100 readings):
  Median RSSI: -49.0 dBm  ← USE THIS VALUE
  Mean RSSI:   -49.2 dBm
  Range:       -53.0 to -46.0 dBm
  Std Dev:     1.91 dB

======================================================================
COPY THIS TO trilateration.py:
======================================================================

RSSI_AT_1M = -48      # Average from receivers: A, B, C

# Individual receiver values:
#   Receiver A: -48 dBm
#   Receiver B: -47 dBm
#   Receiver C: -49 dBm

======================================================================
```

**Calibration Options:**
```bash
# Custom reading count (faster calibration)
python trilateration.py --calibrate --input all_receivers.csv --count 50

# Single receiver calibration
python trilateration.py --calibrate --input all_receivers.csv --receiver A
```

**Step 3: Update Configuration**

Open `trilateration.py` and edit the configuration section:

```python
# RSSI calibration values (calibrate these!)
RSSI_AT_1M = -48      # ← YOUR median RSSI from calibration
PATH_LOSS_N = 2.5     # ← Change based on environment table below
```

**Path Loss Exponent (`n`) Guide:**

| Environment | `PATH_LOSS_N` | Description |
|-------------|---------------|-------------|
| Open outdoor | 2.0 | Free space, no obstacles |
| Open indoor | 2.5 | Large room, minimal walls |
| Indoor with walls | 3.0–3.5 | Tag/receivers separated by walls |
| Heavy obstruction | 4.0–4.5 | Multiple thick walls, metal |
| Tag inside, receivers outside | 4.5–5.0 | Significant penetration loss |

**How to determine your `n`:**
- Start with `n = 2.5` for indoor
- If calculated distances are **too short** → increase `n` (e.g., 3.0, 3.5)
- If calculated distances are **too long** → decrease `n` (e.g., 2.0, 2.5)

**Step 4: Verify Calibration**

```bash
# Show RSSI → distance mapping with your values
python trilateration.py --calibrate

# Test different calibration values without editing file
python trilateration.py --input all_receivers.csv --live --rssi-1m -48 --path-loss 3.0
```

### Receiver Positions

Define physical coordinates in `trilateration.py`:
```python
RECEIVERS = {
    "A": ReceiverPosition(x=0, y=0),    # Origin
    "B": ReceiverPosition(x=0, y=3),    # 3m north
    "C": ReceiverPosition(x=3, y=3),    # 3m east, 3m north
}
```

---

## Output Data Format

### CSV Format (`all_receivers.csv`)
```csv
timestamp_s,receiver_id,rssi_dbm,snr_db
0.123,A,-45,12
0.125,B,-52,9
0.130,C,-48,10
```

### Trilateration Output
```
Position: (1.52, 1.48) m | RSSI: A=-45dBm B=-52dBm C=-48dBm | Dist: A=1.2m B=2.1m C=1.8m
```

---

## Network Considerations

### Same Network Required
All machines must communicate on the same network. Options:
- **Home/Office WiFi** — easiest
- **Mobile Hotspot** — reliable for field work
- **Ethernet** — lowest latency

### Firewall Issues
If connections fail, allow port 8765:

**Windows:**
```powershell
New-NetFirewallRule -DisplayName "LoRa WebSocket" -Direction Inbound -Port 8765 -Protocol TCP -Action Allow
```

**macOS:**
```bash
# System Preferences → Security → Firewall → Allow incoming connections
```

**Linux:**
```bash
sudo ufw allow 8765/tcp
```

### Enterprise Networks (eduroam, etc.)
Many enterprise networks isolate clients. Solutions:
- **Tailscale** — Creates overlay network (recommended)
- **Cloudflare Tunnel** — Tunnels through firewall
- **Mobile hotspot** — Bypass enterprise network entirely

---

## WebSocket Debugging Guide

### Understanding the Connection Flow

```
Receiver B/C (client)  ──→  ws://SERVER_IP:8765/data  ──→  Central Server
```

The receivers connect TO the server, not the other way around.

### Step 1: Verify Server is Running

On **server machine**, after starting `server.py`, you should see:
```
CENTRAL SERVER RUNNING
==============================================================
  Local Receiver: A (on /dev/cu.usbserial-1110)
  WebSocket Server: ws://192.168.1.100:8765
  CSV Output: all_receivers.csv

  Remote receivers should connect to:
    ws://192.168.1.100:8765/data
```

**Check if port is listening:**

**Windows:**
```powershell
netstat -an | Select-String "8765"
# Should show: TCP    0.0.0.0:8765    0.0.0.0:0    LISTENING
```

**macOS/Linux:**
```bash
lsof -i :8765
# Or: netstat -an | grep 8765
# Should show python listening on port 8765
```

### Step 2: Test Network Connectivity

From **receiver machine** (B or C), test if you can reach the server:

```bash
# Ping test
ping SERVER_IP

# Port connectivity test (Windows)
Test-NetConnection SERVER_IP -Port 8765

# Port connectivity test (macOS/Linux)
nc -zv SERVER_IP 8765
# Or: telnet SERVER_IP 8765
```

### Step 3: Test WebSocket Connection Manually

Use a WebSocket test tool or browser console:

**Browser JavaScript Console:**
```javascript
// Open browser developer console (F12) and run:
let ws = new WebSocket("ws://SERVER_IP:8765/data");
ws.onopen = () => console.log("Connected!");
ws.onmessage = (e) => console.log("Message:", e.data);
ws.onerror = (e) => console.error("Error:", e);
```

If this fails, it's a network/firewall issue, not your Python code.

### Common WebSocket Errors

| Error Message | Cause | Solution |
|---------------|-------|----------|
| `Connection refused` | Server not running or wrong port | Start `server.py` first, verify port 8765 |
| `Connection timed out` | Firewall blocking or wrong IP | Check firewall rules, verify SERVER_IP |
| `[Errno 10061]` (Windows) | Server not listening | Ensure server started successfully |
| `Name or service not known` | Invalid SERVER_IP | Double-check IP address with `ipconfig`/`ifconfig` |
| `Connection reset by peer` | Server crashed or restarted | Check server terminal for errors |
| `SSL/TLS error` | Wrong protocol (wss vs ws) | Use `ws://` not `wss://` |
| Connects but no data | Receiver board not sending | Check serial port on receiver machine |

### Debugging Receiver Connection

On **receiver machine**, when running `receiver_B.py`, you should see:

**Success:**
```
REMOTE RECEIVER B
============================================================
  Serial Port: COM5
  Server: ws://192.168.1.100:8765/data
============================================================

[12:34:56] Opening serial port...
[12:34:57] Configuring radio...
[12:34:58] Connected to central server!
[12:34:59] RssiValue=-45 dBm, SnrValue=12dB
[12:35:00] Sent to server: {"timestamp": "...", "rssi": -45, ...}
```

**Failure (connection refused):**
```
[12:34:58] Connecting to ws://192.168.1.100:8765/data...
[12:34:59] Connection refused - is the central server running?
[12:35:00] Retrying in 5 seconds...
```

### Verifying Data Flow

Once receivers connect, check the **server terminal**:

```
[12:34:58] Remote receiver connected from 192.168.1.101
  RX_B:   10.234s | RSSI:  -45 dBm | SNR:  12 dB

[12:35:02] Remote receiver connected from 192.168.1.102
  RX_C:   14.567s | RSSI:  -52 dBm | SNR:   9 dB
```

If receivers connect but no RSSI data appears, the serial port on the receiver machine has an issue.

### Network Isolation Issues

**Symptom:** Ping works, but WebSocket fails.

**Cause:** Some networks (eduroam, corporate) block peer-to-peer but allow internet.

**Test:**
```bash
# This should FAIL if network has client isolation:
ping 192.168.1.101  # Another laptop's IP
```

**Solutions:**
1. Use **mobile hotspot** (easiest)
2. Use **Tailscale VPN** overlay:
   ```bash
   # Install Tailscale on all machines
   # Connect all to same Tailscale network
   # Use Tailscale IPs (100.x.x.x) instead of local IPs
   ```
3. Use **Cloudflare Tunnel**:
   ```bash
   # On server:
   cloudflared tunnel --url http://localhost:8765
   # Gives public URL like: https://abc123.trycloudflare.com
   # Receivers connect to that URL instead
   ```

### Port Already in Use

**Error:** `Address already in use` or `OSError: [Errno 48]`

**Cause:** Another `server.py` instance running, or another program using port 8765.

**Solution:**

**Windows:**
```powershell
# Find what's using port 8765
netstat -ano | Select-String "8765"
# Kill process by PID
taskkill /PID <PID> /F
```

**macOS/Linux:**
```bash
# Find what's using port 8765
lsof -ti:8765
# Kill process
kill $(lsof -ti:8765)
```

---

## Troubleshooting

### General Issues

| Problem | Cause | Solution |
|---------|-------|----------|
| No serial port found | Bad cable or missing driver | Use data cable, install CH340/CP210x driver |
| 100% packet loss | Radio config mismatch | Verify identical `AT+TCONF` on all boards |
| Connection refused | Server not running / firewall | Start server first, open port 8765 |
| Inaccurate positions | Bad calibration | Run `--calibrate --input` mode, adjust path-loss n |
| High RSSI variance | Antenna orientation / reflections | Rotate antenna, move away from metal |

---

### server.py Issues

| Error | Cause | Solution |
|-------|-------|----------|
| `SerialException: could not open port` | Port busy or wrong name | Close other serial apps, verify port with `--list-ports` |
| `OSError: [Errno 48] Address already in use` | Another server running | Kill other `server.py` or use different `--ws-port` |
| `No serial port specified` | Missing `--port` flag | Add `--port COM5` or use `--demo` mode |
| Server starts but no data | Board not in RX mode | Check AT+TRX command was sent (see terminal output) |
| CSV file empty | No receivers connected | Verify receivers show "Connected to central server" |

**Debugging steps:**
```bash
# 1. List available ports
python server.py --list-ports

# 2. Test with demo mode first
python server.py --demo

# 3. Check if port is listening
netstat -an | Select-String "8765"  # Windows
lsof -i :8765                        # macOS/Linux
```

---

### tag.py Issues

| Error | Cause | Solution |
|-------|-------|----------|
| `SerialException: could not open port` | Port busy or wrong name | Close serial monitor, verify port |
| `No serial port specified` | Missing `--port` flag | Add `--port COM3` |
| Tag runs but receivers get nothing | Radio mismatch or antenna issue | Verify AT+TCONF matches, check antenna connection |
| `+TTX: ERROR` response | Board error | Reset board with `ATZ`, check frequency band legal in your region |

**Debugging steps:**
```bash
# 1. List available ports
python tag.py --list-ports

# 2. Test with fewer packets first
python tag.py --port COM3 --packets 3 --interval 5

# 3. Watch receiver terminals for incoming packets
```

---

### receiver_B.py / receiver_C.py Issues

| Error | Cause | Solution |
|-------|-------|----------|
| `Connection refused` | Server not running | Start `server.py` first |
| `Connection timed out` | Wrong IP or firewall | Verify server IP, check firewall allows port 8765 |
| `Name or service not known` | Invalid server URL | Check URL format: `ws://IP:PORT/data` |
| Connects but no RSSI data | Board not receiving | Check serial output, verify AT+TRX was sent |
| `--server is required` | Missing server URL | Add `--server ws://192.168.1.100:8765/data` |
| `WebSocket path must be /data` | Wrong URL path | URL must end with `/data` |

**Debugging steps:**
```bash
# 1. Test network connectivity
ping SERVER_IP
Test-NetConnection SERVER_IP -Port 8765  # Windows
nc -zv SERVER_IP 8765                    # macOS/Linux

# 2. Test with demo mode (no hardware)
python receiver_B.py --demo --server ws://192.168.1.100:8765/data

# 3. Check serial port
python receiver_B.py --list-ports
```

---

### trilateration.py Issues

| Error | Cause | Solution |
|-------|-------|----------|
| `FileNotFoundError: all_receivers.csv` | Server not running or wrong path | Start server first, check `--input` path |
| Position shows `None` | Less than 3 receivers | Ensure all 3 receivers (A, B, C) are sending data |
| All distances show 0.10m | RSSI higher than RSSI_AT_1M | Re-calibrate with `--calibrate --input` |
| Positions wildly inaccurate | Wrong calibration | Run automatic calibration, adjust PATH_LOSS_N |
| Calibration timeout | Not enough data in 60s | Run tag faster: `--packets 20 --interval 3` |
| "No readings collected" | Empty CSV or wrong receiver ID | Check CSV has data, verify receiver_id column |

**Debugging steps:**
```bash
# 1. Check if CSV has data
head all_receivers.csv      # macOS/Linux
Get-Content all_receivers.csv -Head 10  # Windows

# 2. Run without live mode first (processes existing data)
python trilateration.py --input all_receivers.csv

# 3. Test calibration values
python trilateration.py --calibrate

# 4. Try different calibration values
python trilateration.py --input all_receivers.csv --live --rssi-1m -50 --path-loss 3.0
```

---

### Serial Port Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| Port not listed | Driver not installed | Install CH340 (most common) or CP210x driver |
| Port listed but can't open | Another app using it | Close Arduino IDE, PuTTY, or other serial monitors |
| `PermissionError` (Linux) | No permission to access port | Add user to dialout group: `sudo usermod -a -G dialout $USER` |
| Port disappears | USB connection issue | Try different USB port/cable, check board power |
| Garbled output | Wrong baud rate | Ensure 115200 baud in all scripts |

**Driver installation:**
- **CH340**: [Download](http://www.wch-ic.com/downloads/CH341SER_EXE.html)
- **CP210x**: [Download](https://www.silabs.com/developers/usb-to-uart-bridge-vcp-drivers)

---

### LoRa Radio Issues

| Symptom | Cause | Solution |
|---------|-------|----------|
| No AT response | Board not powered or wrong baud | Check USB power LED, verify 115200 baud |
| `+TCONF: ERROR` | Invalid parameter | Check AT+TCONF format matches documentation |
| Tag sends, receivers get nothing | Frequency/SF mismatch | Verify identical AT+TCONF on all boards |
| Very short range (<10m) | Antenna issue | Check antenna connected, try different orientation |
| Intermittent reception | Interference or reflections | Move away from WiFi routers, metal surfaces |

**Radio debugging:**
```bash
# Connect to board with serial terminal and test manually:
# 1. Reset board
ATZ

# 2. Check current config
AT+TCONF?

# 3. Set config (must match all boards!)
AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0

# 4. Start receiving
AT+TRX=9999
```

---

## Advanced Configuration

### Adding More Receivers

1. Copy `receiver_B.py` → `receiver_D.py`
2. Change `RECEIVER_ID = "D"`
3. Add receiver position to `trilateration.py`:
   ```python
   RECEIVERS["D"] = ReceiverPosition(x=3, y=0)
   ```

### Changing Frequency (US 915 MHz)

Update all boards:
```
AT+TCONF=915000000:14:0:7:4/5:1:1:1:16:0:0:0
```

### Higher Range (Lower Data Rate)

Use higher spreading factor:
```
AT+TCONF=868300000:14:0:12:4/5:1:1:1:16:0:0:0
```
SF12 = max range, slowest; SF7 = shortest range, fastest

---

## Project Structure

```
lora_log_collection/
├── FreeRTOS_LoRaWAN_AT.hex    # Custom firmware for Wio-E5 boards
├── server.py                  # Central server (WebSocket + optional local receiver)
├── tag.py                     # Mobile tag transmitter
├── receiver_B.py              # Remote receiver B client
├── receiver_C.py              # Remote receiver C client
├── trilateration.py           # Position calculation
├── position_dashboard.html    # Web visualization
├── requirements.txt           # Python dependencies
├── .github/
│   └── copilot-instructions.md  # AI assistant context
└── README.md                  # This file
```

---

## References

- [Wio-E5 Wiki](https://wiki.seeedstudio.com/LoRa-E5_STM32WLE5JC_Module/)
- [LoRa Modulation Basics](https://www.semtech.com/lora)
- [Log-distance Path Loss Model](https://en.wikipedia.org/wiki/Log-distance_path_loss_model)
- [STM32CubeProgrammer](https://www.st.com/en/development-tools/stm32cubeprog.html)
