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
- Minimum: 1 tag + 3 receivers (more receivers = better accuracy)

### Computers
- Any combination of Windows, macOS, or Linux machines
- One machine acts as central server (runs WebSocket + optionally local receiver)
- Other machines run remote receivers or mobile tag

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

| File | Purpose |
|------|---------|
| `mac_server.py` | Central server + optional local receiver A |
| `windows_tag.py` | Mobile tag transmitter (works on any OS) |
| `windows_receiver_B.py` | Remote receiver B (WebSocket client) |
| `windows_receiver_C.py` | Remote receiver C (WebSocket client) |
| `trilateration.py` | Position calculation from RSSI data |
| `position_dashboard.html` | Web-based visualization |

> **Note:** Despite "mac_" and "windows_" prefixes, all scripts work on any OS. Names indicate original development targets.

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

### 2. Start Central Server

```bash
# With local receiver on server machine
python mac_server.py --port /dev/cu.usbserial-1110  # macOS
python mac_server.py --port COM5                     # Windows
python mac_server.py --port /dev/ttyUSB0             # Linux

# Demo mode (no hardware)
python mac_server.py --demo
```

### 3. Start Remote Receivers

On each receiver machine:
```bash
# Receiver B
python windows_receiver_B.py --port COM5 --server ws://SERVER_IP:8765/data

# Receiver C  
python windows_receiver_C.py --port COM7 --server ws://SERVER_IP:8765/data
```

### 4. Start Mobile Tag

On tag machine (walk around with this!):
```bash
python windows_tag.py --port COM3
```

### 5. Run Trilateration

On server machine:
```bash
python trilateration.py --input all_receivers.csv --live
```

### 6. View Dashboard (Optional)

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

1. **Measure RSSI at 1 meter:**
   - Place tag exactly 1m from each receiver
   - Capture 50–100 packets
   - Use median RSSI value

2. **Update calibration in `trilateration.py`:**
   ```python
   RSSI_AT_1M_PER_RECEIVER = {
       "A": -17,  # Your measured value
       "B": -23,
       "C": -25,
   }
   ```

3. **Adjust path-loss exponent:**
   - Open indoor: n = 2.5
   - Through walls: n = 3.5–4.5
   - Heavy obstruction: n = 4.0–5.0

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

## Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| No serial port found | Bad cable or missing driver | Use data cable, install CH340/CP210x driver |
| 100% packet loss | Radio config mismatch | Verify identical `AT+TCONF` on all boards |
| Connection refused | Server not running / firewall | Start server first, open port 8765 |
| Inaccurate positions | Bad calibration | Measure RSSI at 1m, adjust path-loss n |
| High RSSI variance | Antenna orientation / reflections | Rotate antenna, move away from metal |

---

## Advanced Configuration

### Adding More Receivers

1. Copy `windows_receiver_B.py` → `windows_receiver_D.py`
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
├── mac_server.py              # Central server (any OS)
├── mac_tag.py                 # Backup tag script
├── windows_tag.py             # Mobile tag (any OS)
├── windows_receiver_B.py      # Remote receiver B (any OS)
├── windows_receiver_C.py      # Remote receiver C (any OS)
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
