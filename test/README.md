# TEST Approach - LoRa Testing Setup

## Overview

Testing configurations for validating the LoRa RSSI system.

### Single Receiver Setup
- **1 Mac laptop** - Receiver board + WebSocket server
- **1 Windows laptop** - WebSocket client to view/save data

### Multi-Receiver Setup (3 receivers + 1 sender on Mac)
- **1 Mac laptop** - 3 receiver boards + 1 sender board + WebSocket server
- **1 Windows laptop** - WebSocket client fetching data from all 3 receivers

---

## Multi-Receiver Architecture (NEW)

```
┌─────────────────┐
│  Sender Board   │ ──── LoRa ────┬──────────┬──────────┐
│  (USB to Mac)   │               │          │          │
└────────┬────────┘               ▼          ▼          ▼
         │                 ┌──────────┐ ┌──────────┐ ┌──────────┐
         │                 │Receiver B│ │Receiver C│ │Receiver D│
         │                 └────┬─────┘ └────┬─────┘ └────┬─────┘
         │                      │ USB        │ USB        │ USB
         ▼                      ▼            ▼            ▼
    ┌────────────────────────────────────────────────────────────┐
    │                      Mac Laptop                            │
    │  auto_tag_tx.py    multi_receiver_server.py                │
    │  (sender script)   (3 serial ports + WebSocket server)     │
    │                    Saves: rx_B.csv, rx_C.csv, rx_D.csv     │
    └──────────────────────────┬─────────────────────────────────┘
                               │ WebSocket (WiFi/LAN)
                               ▼
    ┌────────────────────────────────────────────────────────────┐
    │                    Windows Laptop                          │
    │  multi_client.py                                           │
    │  Receives ALL data, saves: rx_B.csv, rx_C.csv, rx_D.csv    │
    └────────────────────────────────────────────────────────────┘
```

---

## Files

| File | Platform | Description |
|------|----------|-------------|
| `multi_receiver_server.py` | Mac | Handles 3 receivers + WebSocket server |
| `multi_client.py` | Windows | Receives from all 3 receivers, saves separate CSVs |
| `receiver_server.py` | Mac | Single receiver + WebSocket server |
| `client.py` | Windows | Single receiver client |
| `auto_tag_tx.py` | Mac | Tag sender script |
| `dashboard.html` | Any | Browser-based viewer |

---

## SETUP: 3 Receivers + 1 Sender on Mac

### Step 1: Connect Hardware to Mac

Connect 4 boards via USB:
- 3 receiver boards
- 1 sender board

### Step 2: Find Serial Ports on Mac

```bash
ls /dev/cu.usb*
```

Example output:
```
/dev/cu.usbserial-1110   # Receiver B
/dev/cu.usbserial-1120   # Receiver C  
/dev/cu.usbserial-1130   # Receiver D
/dev/cu.usbserial-1140   # Sender (Tag)
```

### Step 3: Update Sender Script (if needed)

Edit `auto_tag_tx.py` and set the correct port:
```python
PORT = "/dev/cu.usbserial-1140"  # Your sender port
```

### Step 4: Start Multi-Receiver Server on Mac

```bash
cd test
pip install pyserial websockets

# Start server with 3 receivers
python multi_receiver_server.py \
    --ports /dev/cu.usbserial-1110,/dev/cu.usbserial-1120,/dev/cu.usbserial-1130 \
    --ids B,C,D
```

Expected output:
```
[2025-12-01 14:30:00] Receiver B: Opened /dev/cu.usbserial-1110
[2025-12-01 14:30:00] Receiver B: Configuring radio...
[2025-12-01 14:30:01] Receiver C: Opened /dev/cu.usbserial-1120
[2025-12-01 14:30:01] Receiver C: Configuring radio...
[2025-12-01 14:30:02] Receiver D: Opened /dev/cu.usbserial-1130
[2025-12-01 14:30:02] Receiver D: Configuring radio...
[2025-12-01 14:30:02] WebSocket server started on ws://0.0.0.0:8765
[2025-12-01 14:30:02] Active receivers: B, C, D
```

### Step 5: Start Sender on Mac (separate terminal)

```bash
python auto_tag_tx.py
```

### Step 6: Get Mac's IP Address

```bash
ipconfig getifaddr en0
# Example: 172.20.10.2
```

---

## SETUP: Windows Client

### Step 1: Install Dependencies

```powershell
pip install websockets
```

### Step 2: Run Multi-Client

```powershell
cd d:\lora_log_collection\test
python multi_client.py --server ws://172.20.10.2:8765/data --output-dir ./my_data
```

Expected output:
```
======================================================================
  Multi-Receiver LoRa WebSocket Client
======================================================================
  Server: ws://172.20.10.2:8765/data
  Output: ./my_data
  Press Ctrl+C to stop
======================================================================

[14:32:00] Connecting to ws://172.20.10.2:8765/data...
[14:32:01] Connected! Waiting for data from all receivers...
[14:32:01] Server has receivers: B, C, D
----------------------------------------------------------------------
RX_B:    1.523s | RSSI:  -45 dBm | SNR:  12 dB | ███░ | #1
RX_C:    1.624s | RSSI:  -52 dBm | SNR:  11 dB | ███░ | #1
RX_D:    1.725s | RSSI:  -61 dBm | SNR:  10 dB | ██░░ | #1
RX_B:    2.856s | RSSI:  -44 dBm | SNR:  13 dB | ████ | #2
...
```

### Step 3: Check Output Files

After stopping (Ctrl+C), you'll have:
```
my_data/
├── rx_B.csv
├── rx_C.csv
└── rx_D.csv
```

---

## Quick Test (No Hardware)

### Mac:
```bash
python multi_receiver_server.py --demo
```

### Windows:
```powershell
python multi_client.py --server ws://MAC_IP:8765/data
```

---

## CSV Output Format

Each receiver gets its own CSV file with:

| timestamp_s | rssi_dbm | snr_db |
|-------------|----------|--------|
| 1.523 | -45 | 12 |
| 2.856 | -44 | 13 |

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "No serial ports found" | Check USB connections, run `ls /dev/cu.usb*` |
| "Connection refused" | Start server on Mac first, check IP address |
| No data appearing | Check sender is running, verify radio config matches |
| Wrong receiver order | Check which port corresponds to which physical receiver |
