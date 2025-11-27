# LoRa RSSI Trilateration System

Real-time tag localization using 3 Wio-E5 receivers and RSSI-based trilateration.

## Three Approaches Available

| Approach | Folder | Latency | Reliability | Dashboard | Best For |
|----------|--------|---------|-------------|-----------|----------|
| **Simple** | `simple/` | ~1-2 sec | ⭐⭐⭐ High | ❌ | Learning, debugging |
| **MQTT** | `mqtt/` | ~100ms | ⭐⭐ Medium | ❌ | Existing MQTT infra |
| **WebSocket** ✓ | `websocket/` | ~50-100ms | ⭐⭐⭐ High | ✅ Built-in | **Production use** |

### Recommendation

> **Start with `simple/`** to verify hardware works, then **use `websocket/`** for production.

## Folder Structure

```
lora_log_collection/
│
├── simple/                      # Shared Folder Approach (Easiest)
│   ├── receiver_simple.py       # Run on Windows PCs
│   ├── processor_simple.py      # Run on Mac
│   ├── requirements_simple.txt
│   └── README_SIMPLE.md
│
├── mqtt/                        # MQTT Approach (Real-time)
│   ├── receiver_mqtt.py         # Run on Windows PCs
│   ├── processor_mqtt.py        # Run on Mac
│   ├── visualizer_mqtt.py       # matplotlib visualization
│   ├── requirements_mqtt.txt
│   └── README_MQTT.md
│
└── websocket/                   # WebSocket Approach (Optimal) ✓
    ├── receiver_ws.py           # Run on Windows PCs (auto-reconnect)
    ├── server_ws.py             # Run on Mac (no broker needed)
    ├── dashboard.html           # Web-based live dashboard
    ├── requirements_ws.txt
    └── README_WEBSOCKET.md
```

## Quick Start

### Option 1: Simple Approach (Start Here)

1. **Mac:** Create shared folder and enable File Sharing
2. **Windows:** Connect to `\\<MAC_IP>\lora_data`
3. **Windows:** `pip install pyserial`
4. **Mac:** `pip3 install numpy scipy`

```powershell
# Each Windows PC
python simple/receiver_simple.py --id R1 --output "\\192.168.1.100\lora_data" --x 0 --y 0
```

```bash
# Mac
python3 simple/processor_simple.py --folder ~/lora_data
```

### Option 2: WebSocket Approach (Recommended for Production)

1. **Mac:** `pip3 install websockets numpy scipy`
2. **Windows:** `pip install websockets pyserial`

```bash
# Mac - Start server first
python3 websocket/server_ws.py --port 8765
```

```powershell
# Each Windows PC
python websocket/receiver_ws.py --id R1 --ws-host 192.168.1.100 --x 0 --y 0 --backup ./backup
```

Then open `websocket/dashboard.html` in any browser for live visualization!

### Option 3: MQTT Approach

1. **Mac:** Install Mosquitto: `brew install mosquitto && brew services start mosquitto`
2. **All:** `pip install paho-mqtt pyserial numpy scipy`

```powershell
# Each Windows PC
python mqtt/receiver_mqtt.py --id R1 --mqtt-host 192.168.1.100 --x 0 --y 0
```

```bash
# Mac
python3 mqtt/processor_mqtt.py --mqtt-host localhost
```

## Hardware Setup

### Receiver Placement (Triangle)

```
              R3 (5, 8.66)
                 ▲
                / \
               /   \
              /  ●  \     ← Tag (unknown position)
             /       \
            /         \
           ▲───────────▲
        R1 (0,0)    R2 (10,0)
```

### Wio-E5 Connection
- Connect each Wio-E5 to Windows PC via USB
- Note the COM port (Device Manager → Ports)
- Default baud rate: 9600

## Calibration

For accurate distance estimation:

1. Place tag exactly **1 meter** from a receiver
2. Note the RSSI value (e.g., `-45 dBm`)
3. Use: `--rssi-1m -45`

**Path loss exponent:**
- Open space: `2.0`
- Indoor with furniture: `2.5-3.0`
- Through walls: `3.5-4.0`

## Expected Accuracy

| Environment | Accuracy |
|-------------|----------|
| Open indoor | ±2-3 meters |
| Office space | ±3-5 meters |
| With obstacles | ±5-10 meters |

## Requirements

- Python 3.7+
- 3× Wio-E5 dev boards (receivers)
- 1× LoRa tag/transmitter
- Network connection between all devices

## Detailed Documentation

- **Simple Approach:** See `simple/README_SIMPLE.md`
- **MQTT Approach:** See `mqtt/README_MQTT.md`
- **WebSocket Approach:** See `websocket/README_WEBSOCKET.md`

---

## Approach Comparison

### Simple (Shared Folder)
```
Receivers → CSV Files → Shared Folder → Mac reads files
```
- ✅ No software to install
- ✅ Data never lost (files persist)
- ✅ Easy to debug (just open CSV)
- ❌ 1-2 second delay
- ❌ No live dashboard

### MQTT
```
Receivers → MQTT Broker → Mac subscribes
```
- ✅ True real-time (~100ms)
- ✅ Industry standard for IoT
- ❌ Requires broker installation
- ❌ Messages lost if disconnected
- ❌ More complex setup

### WebSocket (Optimal) ✓
```
Receivers → WebSocket → Mac server → Web Dashboard
```
- ✅ Real-time (~50-100ms)
- ✅ Auto-reconnection built-in
- ✅ Offline buffering (queue + backup)
- ✅ Web dashboard included
- ✅ No external broker needed
- ✅ Works on any browser (phone/tablet)
- ⚠️ Slightly more code complexity
