# 3-Laptop LoRa Setup

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         MAC LAPTOP                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────┐  │
│  │    TAG      │    │ RECEIVER A  │    │ WebSocket       │  │
│  │  (Sender)   │    │   (Local)   │    │ Server :8765    │  │
│  │             │    │             │    │                 │  │
│  └──────┬──────┘    └──────┬──────┘    └────────┬────────┘  │
│         │ USB              │ USB                │           │
│  /dev/cu.usbserial-X   /dev/cu.usbserial-Y      │           │
└─────────────────────────────────────────────────┼───────────┘
                                                  │ WebSocket
                    ┌─────────────────────────────┼───────────────────────────────┐
                    │                             │                               │
                    ▼                             ▼                               │
┌──────────────────────────────┐  ┌──────────────────────────────┐              │
│      WINDOWS LAPTOP 1        │  │      WINDOWS LAPTOP 2        │              │
│  ┌─────────────────────────┐ │  │  ┌─────────────────────────┐ │              │
│  │      RECEIVER B         │ │  │  │      RECEIVER C         │ │              │
│  │                         │ │  │  │                         │ │              │
│  │  windows_receiver_B.py  │ │  │  │  windows_receiver_C.py  │ │              │
│  └──────────┬──────────────┘ │  │  └──────────┬──────────────┘ │              │
│             │ USB (COM5)     │  │             │ USB (COM7)     │              │
└─────────────┴────────────────┘  └─────────────┴────────────────┘              │
                                                                                │
                         Data flows to Mac server ──────────────────────────────┘
```

## Files

| File | Runs On | Purpose |
|------|---------|---------|
| `mac_server.py` | Mac | Receiver A + WebSocket server (aggregates all data) |
| `mac_tag.py` | Mac | Tag/sender (transmits LoRa packets) |
| `windows_receiver_B.py` | Windows #1 | Receiver B → sends to Mac |
| `windows_receiver_C.py` | Windows #2 | Receiver C → sends to Mac |

## Prerequisites

All 3 laptops need Python packages:
```bash
pip install pyserial websockets
```

---

# Step-by-Step Testing Instructions

## STEP 1: Network Setup

All 3 laptops must be on the **same network**:
- Option A: Same WiFi network
- Option B: Mobile hotspot (more reliable)

### Find Mac IP Address:
```bash
# On Mac terminal:
ifconfig | grep "inet "
# Look for IP like 192.168.x.x or 172.20.10.x
```

**Write down the Mac IP: ____________**

---

## STEP 2: Connect Hardware

### On Mac:
1. Connect **2 USB cables** to the Wio-E5 boards
2. Find the ports:
   ```bash
   python3 -c "from serial.tools import list_ports; [print(p.device) for p in list_ports.comports()]"
   ```
3. Note which port is TAG and which is RECEIVER:
   - Tag port: `/dev/cu.usbserial-____`
   - Receiver A port: `/dev/cu.usbserial-____`

### On Windows Laptop 1:
1. Connect **1 USB cable** to Wio-E5 board
2. Open Device Manager → Ports (COM & LPT)
3. Note the COM port: `COM____` (e.g., COM5)

### On Windows Laptop 2:
1. Connect **1 USB cable** to Wio-E5 board
2. Open Device Manager → Ports (COM & LPT)
3. Note the COM port: `COM____` (e.g., COM7)

---

## STEP 3: Test in Demo Mode First (No Hardware Needed)

This verifies network connectivity before using real hardware.

### 3.1 Start Mac Server (Terminal 1 on Mac):
```bash
cd test/3laptop_setup
python3 mac_server.py --demo
```

You'll see:
```
MAC SERVER RUNNING
  Local Receiver: A (on DEMO)
  WebSocket Server: ws://172.20.10.2:8765
  
  Windows receivers should connect to:
    ws://172.20.10.2:8765/data
```

### 3.2 Start Windows Receiver B (Windows Laptop 1):
```bash
cd test\3laptop_setup
python windows_receiver_B.py --demo --server ws://MAC_IP:8765/data
```
Replace `MAC_IP` with actual Mac IP (e.g., `ws://172.20.10.2:8765/data`)

### 3.3 Start Windows Receiver C (Windows Laptop 2):
```bash
cd test\3laptop_setup
python windows_receiver_C.py --demo --server ws://MAC_IP:8765/data
```

### 3.4 Verify Demo Mode
On Mac, you should see readings from A, B, and C:
```
  RX_A:    1.500s | RSSI:  -52 dBm | SNR:  12 dB
  RX_B:    1.234s | RSSI:  -48 dBm | SNR:   9 dB
  RX_C:    1.345s | RSSI:  -55 dBm | SNR:  11 dB
```

**Press Ctrl+C on all terminals to stop demo mode.**

---

## STEP 4: Test with Real Hardware

### 4.1 Start Mac Server with Real Receiver A (Terminal 1):
```bash
python3 mac_server.py --port /dev/cu.usbserial-XXXX
```
Replace `XXXX` with your actual receiver port.

### 4.2 Start Mac Tag/Sender (Terminal 2 on Mac):
```bash
python3 mac_tag.py --port /dev/cu.usbserial-YYYY
```
Replace `YYYY` with your actual tag port (different from receiver!).

### 4.3 Start Windows Receiver B (Windows Laptop 1):
```bash
python windows_receiver_B.py --port COM5 --server ws://MAC_IP:8765/data
```

### 4.4 Start Windows Receiver C (Windows Laptop 2):
```bash
python windows_receiver_C.py --port COM7 --server ws://MAC_IP:8765/data
```

---

## STEP 5: Verify Data Collection

### On Mac Terminal:
Watch for readings from all 3 receivers (A, B, C):
```
  RX_A:   12.345s | RSSI:  -45 dBm | SNR:  12 dB
  RX_B:   12.567s | RSSI:  -52 dBm | SNR:   9 dB
  RX_C:   12.890s | RSSI:  -48 dBm | SNR:  10 dB
```

### Check Output CSV:
The Mac server saves all data to `all_receivers.csv`:
```csv
timestamp_s,receiver_id,rssi_dbm,snr_db
12.345,A,-45,12
12.567,B,-52,9
12.890,C,-48,10
```

---

## Troubleshooting

### "Connection refused" on Windows:
- Mac server not running
- Wrong IP address
- Firewall blocking port 8765

**Fix**: On Mac, allow incoming connections:
```bash
# Check if port is listening
lsof -i :8765
```

### "Cannot open COM port":
- Port is wrong
- Another program using the port
- Board not connected

**Fix**: List available ports:
```bash
python -c "from serial.tools import list_ports; [print(p.device) for p in list_ports.comports()]"
```

### No readings received:
- Tag not transmitting
- Radio config mismatch
- Receivers not in RX mode

**Fix**: Check that `AT+TCONF` settings are identical on ALL boards.

### Receivers B/C connect but no data on Mac:
- Serial port issue on Windows
- LoRa packets not being received

**Fix**: Check Windows terminal - it should show local readings before sending.

---

## Quick Start Commands

### Mac Terminal 1 (Server):
```bash
python3 mac_server.py --port /dev/cu.usbserial-1110
```

### Mac Terminal 2 (Tag):
```bash
python3 mac_tag.py --port /dev/cu.usbserial-1120
```

### Windows Laptop 1 (Receiver B):
```bash
python windows_receiver_B.py --port COM5 --server ws://172.20.10.2:8765/data
```

### Windows Laptop 2 (Receiver C):
```bash
python windows_receiver_C.py --port COM7 --server ws://172.20.10.2:8765/data
```

---

## Output

All data is saved on the Mac in `all_receivers.csv` with columns:
- `timestamp_s` - seconds since start
- `receiver_id` - A, B, or C
- `rssi_dbm` - signal strength
- `snr_db` - signal-to-noise ratio
