# MQTT Approach - Real-time LoRa Tracking

Real-time tag localization using MQTT for low-latency data transfer.

## Architecture

```
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  Windows PC 1   │  │  Windows PC 2   │  │  Windows PC 3   │
│  receiver_mqtt  │  │  receiver_mqtt  │  │  receiver_mqtt  │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         │ MQTT publish       │ MQTT publish       │ MQTT publish
         │                    │                    │
         └────────────────────┼────────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   MQTT Broker     │
                    │  (Mosquitto)      │
                    │   Port 1883       │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │       Mac         │
                    │  processor_mqtt   │
                    │  visualizer_mqtt  │
                    └───────────────────┘
```

## Setup Instructions

### Step 1: Install MQTT Broker on Mac

```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Mosquitto
brew install mosquitto

# Start Mosquitto
brew services start mosquitto
```

**Configure for remote connections:**

Edit config file:
```bash
# Apple Silicon Mac
nano /opt/homebrew/etc/mosquitto/mosquitto.conf

# Intel Mac
nano /usr/local/etc/mosquitto/mosquitto.conf
```

Add these lines:
```conf
listener 1883 0.0.0.0
allow_anonymous true
```

Restart:
```bash
brew services restart mosquitto
```

**Get your Mac's IP:**
```bash
ipconfig getifaddr en0
```

### Step 2: Install Dependencies

**Windows PCs:**
```powershell
pip install paho-mqtt pyserial
```

**Mac:**
```bash
pip3 install paho-mqtt numpy scipy matplotlib
```

### Step 3: Run the System

**Start Processor on Mac first:**
```bash
python3 processor_mqtt.py --mqtt-host localhost
```

**Start Receivers on Windows PCs:**

```powershell
# PC 1 - Position (0, 0)
python receiver_mqtt.py --id R1 --mqtt-host 192.168.1.100 --x 0 --y 0

# PC 2 - Position (10, 0)
python receiver_mqtt.py --id R2 --mqtt-host 192.168.1.100 --x 10 --y 0

# PC 3 - Position (5, 8.66)
python receiver_mqtt.py --id R3 --mqtt-host 192.168.1.100 --x 5 --y 8.66
```

**(Optional) Start Visualizer on Mac:**
```bash
python3 visualizer_mqtt.py --mqtt-host localhost
```

## Command Line Options

### receiver_mqtt.py
| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `--id` | Yes | Receiver ID (R1, R2, R3) | - |
| `--mqtt-host` | Yes | Mac's IP address | - |
| `--mqtt-port` | No | MQTT port | 1883 |
| `--serial-port` | No | COM port (auto-detect) | Auto |
| `--baud-rate` | No | Serial baud rate | 9600 |
| `--x`, `--y`, `--z` | No | Position in meters | 0, 0, 0 |

### processor_mqtt.py
| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `--mqtt-host` | No | MQTT broker IP | localhost |
| `--mqtt-port` | No | MQTT port | 1883 |
| `--time-window` | No | Grouping window (ms) | 500 |
| `--min-receivers` | No | Minimum receivers | 3 |
| `--rssi-1m` | No | RSSI at 1 meter | -40 |
| `--path-loss` | No | Path loss exponent | 2.5 |
| `--3d` | No | Enable 3D mode | False |

### visualizer_mqtt.py
| Option | Required | Description | Default |
|--------|----------|-------------|---------|
| `--mqtt-host` | No | MQTT broker IP | localhost |
| `--mqtt-port` | No | MQTT port | 1883 |
| `--width` | No | Room width (m) | 10 |
| `--height` | No | Room height (m) | 10 |

## Receiver Placement

Triangular formation for best accuracy:

```
            R3 (5, 8.66)
               ▲
              / \
             /   \
            /  ●  \      ← Tag
           /       \
          /         \
         ▲───────────▲
      R1 (0,0)    R2 (10,0)
```

## Calibration

1. Place tag at exactly 1 meter from a receiver
2. Note the RSSI value
3. Use with: `--rssi-1m <value>`

**Path loss exponent guide:**
| Environment | Value |
|-------------|-------|
| Free space | 2.0 |
| Open indoor | 2.5 |
| Indoor with furniture | 3.0 |
| Through walls | 3.5-4.0 |

## Troubleshooting

### Can't connect to MQTT broker
```bash
# Check if Mosquitto is running
brew services list

# Check firewall
# System Preferences → Security → Firewall → Allow Mosquitto

# Test connection
mosquitto_pub -h localhost -t test -m "hello"
mosquitto_sub -h localhost -t test
```

### Receivers can't connect
- Check Mac IP address is correct
- Verify Windows firewall allows outbound on port 1883
- Ping Mac from Windows: `ping 192.168.1.100`

### No position output
- Ensure all 3 receivers are publishing
- Check time synchronization between PCs (use NTP)
- Increase `--time-window` if clocks are slightly off

## MQTT vs Shared Folder

| Aspect | MQTT | Shared Folder |
|--------|------|---------------|
| Latency | ~100ms | ~1-2 seconds |
| Setup | More complex | Easy |
| Dependencies | MQTT broker | None |
| Reliability | Medium | High |
| Best for | Real-time tracking | Near-real-time |
