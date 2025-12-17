# GitHub Copilot Instructions for LoRa Log Collection Project

## Project Overview

This is a **LoRa RSSI/SNR log collection system** for indoor positioning research. It collects signal strength (RSSI) and signal-to-noise ratio (SNR) data from multiple LoRa receiver boards and streams them to a central location for analysis.

### Architecture - 3-Laptop Production Setup
```
┌─────────────────────────────────────────────┐
│              MAC LAPTOP (Server)            │
│  ┌─────────┐  ┌────────────┐  ┌──────────┐ │
│  │   TAG   │  │ Receiver A │  │WebSocket │ │
│  │(Sender) │  │  (Local)   │  │Server    │ │
│  └────┬────┘  └─────┬──────┘  └────┬─────┘ │
│       │USB          │USB           │:8765  │
└───────┼─────────────┼──────────────┼───────┘
        │             │              │
        │             │    ┌─────────┴──────────┐
        │             │    │                    │
        │             │    ▼                    ▼
        │             │  ┌──────────────┐  ┌──────────────┐
        │             │  │  WINDOWS #1  │  │  WINDOWS #2  │
        │             │  │  Receiver B  │  │  Receiver C  │
        │             │  │  (COM5/7)    │  │  (COM5/7)    │
        │             │  └──────────────┘  └──────────────┘
        │             │         │                  │
        └─────────────┴─────────┴──────────────────┘
         LoRa packets broadcast to all receivers
```

**Data Flow**: Tag broadcasts LoRa → All receivers (A,B,C) capture RSSI → B&C send via WebSocket to Mac → Mac aggregates all data → Trilateration calculates tag position

## Key Technologies

- **Python 3.7+** with `pyserial` and `websockets` libraries
- **LoRa Hardware**: Wio-E5 development boards with AT command interface
- **Communication**: WebSocket (preferred), MQTT, or shared folder approaches
- **Data Format**: CSV with timestamp, RSSI, SNR columns

## LoRa AT Commands Reference

When working with LoRa board communication, use these AT commands:

| Command | Purpose | Example |
|---------|---------|---------|
| `ATZ` | Reset board | `ser.write(b"ATZ\r\n")` |
| `AT+TCONF` | Configure radio | `AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0` |
| `AT+TRX=N` | Receive N packets | `AT+TRX=9999` (continuous) |
| `AT+TTX=N` | Transmit N packets | `AT+TTX=10` |

### Radio Configuration Format
```
AT+TCONF=<frequency>:<power>:<bandwidth>:<spreading_factor>:<coding_rate>:<lna>:<pa>:<crc>:<preamble>:<payload_len>:<implicit_header>:<iq_invert>
```
Standard config: `868300000:14:0:7:4/5:1:1:1:16:0:0:0`

## Data Format Patterns

### LoRa Board Output Format
```
RssiValue=-45 dBm, SnrValue=12dB
```

### Regex Pattern (Python)
```python
RSSI_PATTERN = re.compile(r"RssiValue=(-?\d+)\s*dBm,\s*SnrValue=(-?\d+)dB")
```

### CSV Output Format
```csv
timestamp_s,rssi_dbm,snr_db
0.123,-45,12
1.456,-48,10
```

For multi-receiver setups, add `receiver_id` column:
```csv
timestamp_s,receiver_id,rssi_dbm,snr_db
0.123,B,-45,12
0.125,C,-52,8
```

## Serial Port Conventions

### Cross-Platform Port Detection
```python
import sys

if sys.platform == "win32":
    PORT = "COM5"  # or COM7, COM8, etc.
else:
    PORT = "/dev/cu.usbserial-1110"  # Mac uses cu.usbserial-XXXX
```

### Standard Configuration
- **Baud Rate**: 115200
- **Timeout**: 1 second
- **Line Ending**: `\r\n` for AT commands

## Code Patterns

### Basic Serial Communication
```python
import serial
ser = serial.Serial(PORT, 115200, timeout=1)
ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
time.sleep(0.5)
ser.read_all()  # Clear response buffer
```

### WebSocket Server Pattern
```python
import websockets
from websockets.server import serve

async def handler(websocket, path):
    if path == "/data":
        data_clients.add(websocket)
    elif path == "/dashboard":
        dashboard_clients.add(websocket)

async with serve(handler, "0.0.0.0", 8765):
    await asyncio.Future()
```

### WebSocket Client Pattern
```python
async with websockets.connect(f"ws://{SERVER_IP}:8765/data") as ws:
    async for message in ws:
        data = json.loads(message)
        # Process data
```

## Project Structure

```
lora_log_collection/
├── mac_server.py           # Mac: Receiver A + WebSocket server + aggregates all data
├── mac_tag.py              # BACKUP: Tag for Mac (use windows_tag.py instead)
├── windows_tag.py          # Windows #1: MOBILE LoRa tag/sender (walk around with this!)
├── windows_receiver_B.py   # Windows #2: Receiver B → WebSocket client
├── windows_receiver_C.py   # Windows #3: Receiver C → WebSocket client
├── trilateration.py        # Real-time (X,Y) position from 3 RSSI values
├── position_dashboard.html # Web UI for visualizing tag position
├── requirements.txt        # Python dependencies (pyserial, websockets)
└── README.md               # Setup guide with network/hardware steps
```

**Key Concept**: Mac runs only receiver A + WebSocket server. Windows #1 has the MOBILE TAG (moves around). Windows #2 and #3 run static receivers (B,C) that stream data to Mac. All RSSI readings are saved to `all_receivers.csv` on Mac for trilateration processing.

## Common Patterns When Generating Code

### 1. Always Handle Serial Timeouts
```python
line = ser.readline().decode(errors="ignore").strip()
if not line:
    continue
```

### 2. Use Async for WebSocket Operations
```python
async def read_serial(receiver_id: str):
    loop = asyncio.get_event_loop()
    line = await loop.run_in_executor(
        None,
        lambda: ser.readline().decode('utf-8', errors='replace')
    )
```

### 3. Flush CSV After Each Write
```python
writer.writerow([timestamp, rssi, snr])
csv_file.flush()  # Ensure data is written immediately
```

### 4. Handle Keyboard Interrupts Gracefully
```python
try:
    while True:
        # Main loop
except KeyboardInterrupt:
    print("Stopping...")
finally:
    ser.close()
```

## Testing Conventions

### Demo Mode
When hardware is unavailable, scripts should support `--demo` flag:
```python
if args.demo:
    rssi = random.randint(-70, -40)
    snr = random.randint(5, 15)
```

### Port Discovery
List available ports for debugging:
```python
from serial.tools import list_ports
for port in list_ports.comports():
    print(f"{port.device}: {port.description}")
```

## Environment Setup

### Required Packages
```bash
pip install pyserial websockets
```

### For MQTT approach (optional)
```bash
pip install paho-mqtt
```

## Network Configuration

- **WebSocket Port**: 8765 (default)
- **Endpoints**: 
  - `/data` - JSON data stream
  - `/dashboard` - Dashboard client connection

## Error Handling Guidelines

1. **Serial port busy**: Another script may be using the same port
2. **100% packet loss**: Check radio configuration matches on TX and RX
3. **Connection refused**: Ensure firewall allows port 8765
4. **No data received**: Verify AT+TRX command was sent and acknowledged

## Indoor Positioning with Trilateration

### Coordinate System Setup
1. **Place receivers** at measured positions (e.g., A at origin 0,0; B at 0,6m; C at 8,6m)
2. **Define in trilateration.py**:
   ```python
   RECEIVERS = {
       "A": (0, 0),      # Origin at receiver A
       "B": (0, 6),      # 6 meters north
       "C": (8, 6)       # 8 meters east, 6 meters north
   }
   ```

### RSSI Calibration
Critical for accurate distance estimation:
```bash
# 1. Place tag exactly 1 meter from receiver A
# 2. Run server to capture RSSI readings
python3 mac_server.py --port /dev/cu.usbserial-1110

# 3. Observe RSSI values in all_receivers.csv (e.g., -15 dBm)
# 4. Use this value in trilateration.py:
RSSI_AT_1M = -15  # Measured RSSI at 1 meter distance
PATH_LOSS_N = 2.5  # Indoor path loss exponent
```

**Distance Formula**:
```python
distance = 10 ** ((rssi_1m - rssi) / (10 * n))
```
If `rssi >= rssi_1m`, returns minimum distance of 0.1m

### Running Trilateration
```bash
# Real-time position tracking
python3 trilateration.py --input all_receivers.csv --live --rssi-1m -15

# Calibration mode (test with various RSSI_AT_1M values)
python3 trilateration.py --input all_receivers.csv --live --rssi-1m -15 --calibrate

# Monitor individual distances for debugging
python3 live_distance.py --input all_receivers.csv --rssi-1m -15
```

**Output Format**:
```
Position: (4.12, 2.85) m | RSSI: A=-14dBm B=-47dBm C=-18dBm
```

## 4-Laptop Production Deployment

### Step-by-Step Commands

**1. Mac Laptop (Server + Receiver A Only)**
```bash
# Terminal 1: Start server with local receiver A
python3 mac_server.py --port /dev/cu.usbserial-1110

# Terminal 2: Real-time position tracking
python3 trilateration.py --input all_receivers.csv --live --rssi-1m -15
```

**2. Windows Laptop #1 (MOBILE TAG - Walk Around!)**
```powershell
python windows_tag.py --port COM5
# 📍 Move around the room with this laptop to test positioning!
```

**3. Windows Laptop #2 (Receiver B - Stationary)**
```powershell
python windows_receiver_B.py --port COM5 --server ws://192.168.1.10:8765/data
```

**4. Windows Laptop #3 (Receiver C - Stationary)**
```powershell
python windows_receiver_C.py --port COM7 --server ws://192.168.1.10:8765/data
```

### Network Setup
```bash
# Find Mac IP address
ipconfig getifaddr en0  # Mac WiFi
ipconfig getifaddr en1  # Mac Ethernet

# Test connectivity from Windows
ping 192.168.1.10
```

### Data Flow Verification
1. **Tag (Win #1, mobile)** sends LoRa packets every 7 seconds (10-packet bursts)
2. **All receivers** (A on Mac, B & C on Windows) capture packets with RSSI/SNR
3. **Receivers B & C** stream data via WebSocket to Mac server
4. **Mac server** aggregates all data (A local, B & C remote) to `all_receivers.csv`
5. **Trilateration script** reads CSV and calculates tag's (X,Y) position as you move

## Troubleshooting Common Issues

### Distances Stuck at 0.10m
**Cause**: RSSI_AT_1M calibration value too low
```python
# If actual RSSI is -10 dBm but RSSI_AT_1M=-45:
# rssi >= rssi_1m → distance clamped to 0.1m minimum
```
**Solution**: Measure actual RSSI at 1m (typically -10 to -20 dBm for close range)

### Only One Receiver Distance Changes
**Cause**: Other receivers returning minimum distance due to calibration
**Solution**: 
1. Verify all receivers in `all_receivers.csv` have recent timestamps
2. Check RSSI values in output: `RSSI: A=-14dBm B=-47dBm C=-18dBm`
3. Ensure RSSI_AT_1M is lower than actual received RSSI values

### WebSocket Connection Refused
- Verify firewall allows port 8765
- Check Mac server IP with `ipconfig getifaddr en0`
- Ensure server script shows "WebSocket server started on port 8765"

### 100% Packet Loss
- Verify AT+TCONF matches on tag and all receivers
- Check antenna connections
- Ensure receivers are in RX mode (`AT+TRX=9999`)

## When Modifying This Project

1. **Adding a new receiver**: Copy `windows_receiver_C.py`, update PORT and RECEIVER_ID
2. **Changing frequency**: Update `AT+TCONF` in windows_tag.py and all receiver scripts
3. **Adding dashboard features**: Modify `position_dashboard.html` and WebSocket handler in `mac_server.py`
4. **Cross-platform support**: Always use `sys.platform` check for serial ports
5. **Adjusting coordinate system**: Measure new receiver positions, update `RECEIVERS` dict in `trilateration.py`
6. **Testing without hardware**: Add `--demo` flag to generate random RSSI values
