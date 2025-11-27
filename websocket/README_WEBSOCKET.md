# WebSocket Approach - Optimal Balance

The **best of both worlds**: real-time streaming like MQTT, but with built-in reliability features.

## Why This is Optimal

| Feature | Simple (CSV) | MQTT | WebSocket ✓ |
|---------|--------------|------|-------------|
| Latency | ~1-2 sec | ~100ms | ~50-100ms |
| Auto-reconnect | N/A | Manual | ✅ Built-in |
| Offline buffering | ✅ Files | ❌ Lost | ✅ Queue + Backup |
| Web dashboard | ❌ | ❌ | ✅ Included |
| Bidirectional | ❌ | ✅ | ✅ |
| External broker | ❌ | ✅ Required | ❌ Not needed |
| Setup complexity | ⭐ | ⭐⭐⭐ | ⭐⭐ |

## Architecture

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Windows PC 1   │  │  Windows PC 2   │  │  Windows PC 3   │
│  receiver_ws.py │  │  receiver_ws.py │  │  receiver_ws.py │
│  + Local Backup │  │  + Local Backup │  │  + Local Backup │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         │ WebSocket          │ WebSocket          │ WebSocket
         │ (auto-reconnect)   │ (auto-reconnect)   │ (auto-reconnect)
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │       Mac         │
                    │   server_ws.py    │
                    │   Port 8765       │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Web Dashboard    │
                    │  dashboard.html   │
                    │  (open in browser)│
                    └───────────────────┘
```

## Key Features

### 1. Automatic Reconnection
If network drops, receivers automatically reconnect and send queued messages.

### 2. Offline Buffering
Messages are queued locally when disconnected (up to 1000 messages).

### 3. Local Backup
Optional CSV backup on each receiver - never lose data.

### 4. Web Dashboard
Real-time visualization in any browser - no matplotlib needed.

### 5. No External Broker
WebSocket server is built into the central processor.

## Setup Instructions

### Step 1: Install Dependencies

**Windows PCs (Receivers):**
```powershell
pip install websockets pyserial
```

**Mac (Server):**
```bash
pip3 install websockets numpy scipy
```

### Step 2: Get Mac's IP Address

```bash
ipconfig getifaddr en0
```
Note the IP (e.g., `192.168.1.100`)

### Step 3: Run the System

**Start Server on Mac first:**
```bash
cd websocket
python3 server_ws.py --port 8765
```

**Start Receivers on Windows PCs:**
```powershell
# PC 1 - Position (0, 0) with local backup
python receiver_ws.py --id R1 --ws-host 192.168.1.100 --x 0 --y 0 --backup ./backup

# PC 2 - Position (10, 0)
python receiver_ws.py --id R2 --ws-host 192.168.1.100 --x 10 --y 0 --backup ./backup

# PC 3 - Position (5, 8.66)
python receiver_ws.py --id R3 --ws-host 192.168.1.100 --x 5 --y 8.66 --backup ./backup
```

**Open Dashboard (any device on network):**
```
http://192.168.1.100:8080/dashboard.html
```
Or just open `dashboard.html` locally and it will connect.

## Command Line Options

### receiver_ws.py
| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `--id` | Yes | Receiver ID (R1, R2, R3) | - |
| `--ws-host` | Yes | Server IP address | - |
| `--ws-port` | No | WebSocket port | 8765 |
| `--serial-port` | No | COM port (auto-detect) | Auto |
| `--baud-rate` | No | Serial baud rate | 9600 |
| `--x`, `--y` | No | Position in meters | 0, 0 |
| `--backup` | No | Local backup folder | None |

### server_ws.py
| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `--host` | No | Bind address | 0.0.0.0 |
| `--port` | No | WebSocket port | 8765 |
| `--time-window` | No | Grouping window (ms) | 500 |
| `--min-receivers` | No | Minimum receivers | 3 |
| `--rssi-1m` | No | RSSI at 1 meter | -40 |
| `--path-loss` | No | Path loss exponent | 2.5 |

## Dashboard Features

The web dashboard (`dashboard.html`) provides:

- **Live map** with tag position and receiver locations
- **Position trail** showing movement history
- **Real-time RSSI** values from each receiver
- **Connection status** indicator
- **Message/position counters**
- **Event log**

Just open in any modern browser - works on phone/tablet too!

## Reliability Features

### Network Disconnection Handling

```
Receiver                          Server
   │                                │
   ├──── Send data ────────────────►│  ✓ Normal operation
   │                                │
   │     [Network drops]            │
   │                                │
   ├──── Queue locally ────────────X│  Messages buffered
   ├──── Queue locally ────────────X│
   ├──── Queue locally ────────────X│
   │                                │
   │     [Network restored]         │
   │                                │
   ├──── Reconnect ────────────────►│  Auto-reconnect
   ├──── Flush queue ──────────────►│  Send all buffered
   ├──── Normal operation ─────────►│  ✓ Back to normal
   │                                │
```

### Local Backup

Each receiver can maintain a CSV backup:

```csv
timestamp,timestamp_ms,receiver_id,pos_x,pos_y,rssi,snr,sent
2025-11-27T10:30:15.123,1732703415123,R1,0,0,-45,12,yes
2025-11-27T10:30:15.456,1732703415456,R1,0,0,-47,11,no  ← was offline
2025-11-27T10:30:15.789,1732703415789,R1,0,0,-44,13,yes
```

## Comparison Summary

| Aspect | Simple | MQTT | WebSocket |
|--------|--------|------|-----------|
| **Best for** | Learning, debugging | Existing MQTT infra | Production use |
| **Latency** | High | Low | Low |
| **Reliability** | High | Medium | High |
| **Visualization** | None | Separate | Built-in |
| **Dependencies** | Minimal | MQTT broker | None |
| **Offline handling** | Automatic | Lost | Queued |

## When to Use Each Approach

- **Simple (CSV)**: Testing, debugging, don't need real-time
- **MQTT**: Already have MQTT infrastructure, need pub/sub
- **WebSocket**: Production use, need real-time + reliability + dashboard
