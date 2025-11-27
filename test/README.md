# TEST Approach - Single Board Testing

## Overview

This is a **testing configuration** for validating the system with minimal hardware:
- **1 Mac laptop** - Has receiver board connected via USB, runs WebSocket server
- **1 Windows laptop** - Connects as WebSocket client to view real-time data
- **1 LoRa sender board** - Transmits test packets
- **1 LoRa receiver board** - Connected to Mac, receives packets

## Architecture

```
┌─────────────────┐     LoRa     ┌─────────────────┐
│  Sender Board   │ ~~~~~~~~~~> │  Receiver Board │
│  (standalone)   │   wireless  │   (USB to Mac)  │
└─────────────────┘             └────────┬────────┘
                                         │ Serial
                                         ▼
                               ┌─────────────────────┐
                               │     Mac Laptop      │
                               │  receiver_server.py │
                               │  - Reads serial     │
                               │  - WebSocket server │
                               │  - Serves dashboard │
                               └──────────┬──────────┘
                                          │ WebSocket
                                          │ (WiFi/LAN)
                                          ▼
                               ┌─────────────────────┐
                               │   Windows Laptop    │
                               │   - Dashboard view  │
                               │   - OR client.py    │
                               └─────────────────────┘
```

## Files

| File | Platform | Description |
|------|----------|-------------|
| `receiver_server.py` | Mac | Reads serial + runs WebSocket server |
| `client.py` | Windows | Python client to receive and display data |
| `dashboard.html` | Any | Browser-based real-time viewer |

## Setup Instructions

### Step 1: Mac Setup (Receiver + Server)

1. Connect the receiver board to Mac via USB

2. Install dependencies:
   ```bash
   pip install pyserial websockets
   ```

3. Find your serial port:
   ```bash
   ls /dev/cu.*
   # Look for something like /dev/cu.usbserial-XXXX or /dev/cu.usbmodem-XXXX
   ```

4. Run the receiver server:
   ```bash
   python receiver_server.py --port /dev/cu.usbserial-XXXX
   ```
   
   The server will start on `ws://0.0.0.0:8765`

5. Note your Mac's IP address:
   ```bash
   ipconfig getifaddr en0   # WiFi
   # or
   ipconfig getifaddr en1   # Ethernet
   ```

### Step 2: Windows Client Setup

**Option A: Browser Dashboard (Easiest)**

1. Open `dashboard.html` in a text editor
2. Change the WebSocket URL to your Mac's IP:
   ```javascript
   const ws = new WebSocket('ws://YOUR_MAC_IP:8765/dashboard');
   ```
3. Open `dashboard.html` in your browser

**Option B: Python Client**

1. Install dependencies:
   ```powershell
   pip install websockets
   ```

2. Run the client:
   ```powershell
   python client.py --server ws://YOUR_MAC_IP:8765/data
   ```

### Step 3: Power the Sender Board

Power on or reset your sender board. It should start transmitting LoRa packets.

## Expected Output

### Mac Terminal (receiver_server.py)
```
[2025-01-15 10:30:01] Serial port /dev/cu.usbserial-1420 opened
[2025-01-15 10:30:01] WebSocket server started on ws://0.0.0.0:8765
[2025-01-15 10:30:05] Dashboard client connected from 192.168.1.50
[2025-01-15 10:30:10] RX: tag=TAG001, rssi=-45, snr=12
[2025-01-15 10:30:11] RX: tag=TAG001, rssi=-47, snr=11
```

### Windows Terminal (client.py)
```
Connected to ws://192.168.1.100:8765/data
[10:30:10] TAG001 | RSSI: -45 dBm | SNR: 12
[10:30:11] TAG001 | RSSI: -47 dBm | SNR: 11
```

## Testing Checklist

- [ ] Mac can read serial data from receiver board
- [ ] WebSocket server starts without errors
- [ ] Windows can connect to WebSocket server
- [ ] Data appears in real-time on Windows
- [ ] Dashboard shows live updates

## Troubleshooting

### "Permission denied" on Mac serial port
```bash
sudo chmod 666 /dev/cu.usbserial-XXXX
```

### Windows can't connect to WebSocket
1. Check Mac's firewall allows port 8765
2. Verify both devices are on the same network
3. Test with: `curl http://MAC_IP:8765` (should fail with WebSocket error, but confirms connectivity)

### No data appearing
1. Check sender board is powered and transmitting
2. Verify serial port is correct on Mac
3. Check receiver board LED for activity

## Message Format

The receiver expects LoRa packets in this format:
```
+RX "48454C4C4F",-45,12
```
Where:
- `48454C4C4F` = Hex-encoded payload (e.g., "HELLO")
- `-45` = RSSI in dBm
- `12` = SNR

The server broadcasts JSON to clients:
```json
{
  "timestamp": "2025-01-15T10:30:10.123456",
  "tag_id": "TAG001",
  "rssi": -45,
  "snr": 12,
  "raw_payload": "48454C4C4F"
}
```
