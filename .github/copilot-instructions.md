# GitHub Copilot Instructions for LoRa Log Collection Project

## Project Overview

This is a **LoRa RSSI/SNR log collection system** for indoor positioning research. It collects signal strength (RSSI) and signal-to-noise ratio (SNR) data from multiple LoRa receiver boards and streams them to a central location for analysis.

### Architecture
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Receiver B  │    │ Receiver C  │    │ Receiver D  │   (Wio-E5 boards)
└──────┬──────┘    └──────┬──────┘    └──────┬──────┘
       │ USB              │ USB              │ USB
       └──────────────────┼──────────────────┘
                          ▼
                ┌─────────────────┐
                │  Mac/Windows PC │  (WebSocket Server)
                └────────┬────────┘
                         │ WebSocket (port 8765)
                         ▼
                ┌─────────────────┐
                │  Remote Client  │  (Windows/Mac)
                └─────────────────┘
```

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
├── auto_rx_B.py          # Standalone receiver B script
├── auto_rx_C.py          # Standalone receiver C script  
├── auto_rx_log.py        # Generic receiver logger
├── auto_tag_tx.py        # Sender/tag script
├── test/                 # WebSocket test implementations
│   ├── receiver_server.py       # Single receiver + WebSocket
│   ├── multi_receiver_server.py # Multi-receiver + WebSocket
│   ├── client.py               # Single client
│   ├── multi_client.py         # Multi-receiver client
│   └── dashboard.html          # Web dashboard
├── websocket/            # Production WebSocket approach
├── mqtt/                 # MQTT broker approach
├── shared_folder/        # Simple file-sharing approach
└── docs/                 # Research documentation
```

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

## When Modifying This Project

1. **Adding a new receiver**: Copy `auto_rx_B.py`, update PORT and OUT_CSV
2. **Changing frequency**: Update `AT+TCONF` in all receiver and sender scripts
3. **Adding dashboard features**: Modify `dashboard.html` and corresponding WebSocket handler
4. **Cross-platform support**: Always use `sys.platform` check for serial ports
