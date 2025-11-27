# Simple LoRa Tracking - Shared Folder Approach

**The easiest and safest method** - no broker installation required!

## Setup Overview

```
Windows PCs write CSV files → Shared Folder → Mac reads & processes
```

## Step 1: Create Shared Folder on Mac

1. **Create the folder:**
   ```bash
   mkdir ~/lora_data
   ```

2. **Enable File Sharing:**
   - System Preferences → Sharing
   - Check "File Sharing"
   - Click "+" and add the `lora_data` folder
   - Click "Options" → Check "Share files and folders using SMB"
   - Note your Mac's IP address shown at the top

3. **Set permissions:**
   - Right-click folder in Options → select "Everyone" → "Read & Write"

## Step 2: Connect Windows PCs to Shared Folder

On each Windows laptop:

1. Open File Explorer
2. In address bar, type: `\\<MAC_IP>\lora_data`
   - Example: `\\192.168.1.100\lora_data`
3. Enter your Mac username and password
4. Right-click → "Map network drive" (optional, for convenience)

## Step 3: Install Python Dependencies

**On Windows PCs:**
```powershell
pip install pyserial
```

**On Mac:**
```bash
pip3 install numpy scipy
```

## Step 4: Run the System

### Start Receivers (Windows)

**PC 1 - Receiver at position (0, 0):**
```powershell
python receiver_simple.py --id R1 --output "\\192.168.1.100\lora_data" --x 0 --y 0
```

**PC 2 - Receiver at position (10, 0):**
```powershell
python receiver_simple.py --id R2 --output "\\192.168.1.100\lora_data" --x 10 --y 0
```

**PC 3 - Receiver at position (5, 8.66):**
```powershell
python receiver_simple.py --id R3 --output "\\192.168.1.100\lora_data" --x 5 --y 8.66
```

### Start Processor (Mac)

```bash
python3 processor_simple.py --folder ~/lora_data
```

## Expected Output

On the Mac, you'll see:
```
==================================================
📍 TAG POSITION: X=4.23m, Y=3.15m
--------------------------------------------------
  R1: RSSI=-48dBm → 2.51m
  R2: RSSI=-55dBm → 4.47m
  R3: RSSI=-52dBm → 3.55m
==================================================
```

## Receiver Placement

Place receivers in a triangle for best accuracy:

```
            R3 (5, 8.66)
               ▲
              / \
             /   \
            /  ●  \      ← Tag somewhere inside
           /       \
          /         \
         ▲───────────▲
      R1 (0,0)    R2 (10,0)
```

## Troubleshooting

### Can't access shared folder from Windows
- Check Mac firewall settings
- Verify both devices are on same network
- Try using Mac's IP address instead of hostname
- Check SMB sharing is enabled in Mac sharing options

### No data appearing in CSV
- Verify COM port is correct (check Device Manager)
- Check Wio-E5 is outputting data (use PuTTY to test)
- Ensure baud rate matches (default: 9600)

### Inaccurate position
- Calibrate RSSI at 1 meter: `--rssi-1m -45`
- Adjust path loss for environment: `--path-loss 3.0`
- Ensure receivers have clear line of sight

## Command Line Options

### receiver_simple.py (Windows)
| Option | Required | Description |
|--------|----------|-------------|
| `--id` | Yes | Receiver ID (R1, R2, R3) |
| `--output` | Yes | Path to shared folder |
| `--x` | Yes | X position in meters |
| `--y` | Yes | Y position in meters |
| `--serial-port` | No | COM port (auto-detect) |
| `--baud-rate` | No | Serial baud rate (default: 9600) |

### processor_simple.py (Mac)
| Option | Required | Description |
|--------|----------|-------------|
| `--folder` | Yes | Path to shared folder |
| `--time-window` | No | Time window in seconds (default: 2.0) |
| `--poll-interval` | No | How often to check files (default: 0.5) |
| `--rssi-1m` | No | RSSI at 1 meter (default: -40) |
| `--path-loss` | No | Path loss exponent (default: 2.5) |

## Comparison: Simple vs MQTT Approach

| Aspect | Simple (Shared Folder) | MQTT |
|--------|------------------------|------|
| Setup time | 5 minutes | 30+ minutes |
| Software to install | None (just Python) | MQTT broker |
| Latency | ~1-2 seconds | ~100ms |
| Reliability | High (files persist) | Medium |
| Debugging | Easy (read CSV files) | Harder |
| Scalability | Good for 3-5 receivers | Better for 10+ |

**Recommendation:** Start with this simple approach. If you need faster updates later, you can switch to MQTT.
