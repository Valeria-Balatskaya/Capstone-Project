#!/usr/bin/env python3
"""
Windows Receiver C - Sends data to Mac Server
==============================================
Runs on Windows laptop #2 with receiver board connected.
- Reads LoRa data from local receiver
- Sends data to Mac server via WebSocket

Setup:
    1. Connect receiver board to Windows USB
    2. Check Device Manager for COM port (e.g., COM7)
    3. Run: python windows_receiver_C.py --port COM7 --server ws://MAC_IP:8765/data
"""

import asyncio
import argparse
import json
import re
import sys
import time
from datetime import datetime

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial")
    sys.exit(1)

try:
    import websockets
except ImportError:
    print("ERROR: websockets not installed. Run: pip install websockets")
    sys.exit(1)


RECEIVER_ID = "C"
RSSI_PATTERN = re.compile(r"RssiValue=(-?\d+)\s*dBm,\s*SnrValue=(-?\d+)dB")


def log(message: str):
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")


def list_ports():
    """List available serial ports."""
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        print("No serial ports found!")
        return []
    
    print("\nAvailable ports:")
    for p in ports:
        print(f"  {p.device}: {p.description}")
    return ports


def configure_radio(ser: serial.Serial):
    """Configure receiver radio."""
    log("Configuring radio...")
    ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
    time.sleep(0.5)
    ser.read_all()
    ser.write(b"AT+TRX=9999\r\n")
    time.sleep(0.5)
    ser.read_all()
    log("Radio configured - listening for packets")


def parse_lora_line(line: str, start_time: float) -> dict:
    """Parse LoRa output line."""
    match = RSSI_PATTERN.search(line)
    if not match:
        return None
    
    return {
        "timestamp": datetime.now().isoformat(),
        "timestamp_s": round(time.time() - start_time, 3),
        "receiver_id": RECEIVER_ID,
        "rssi": int(match.group(1)),
        "snr": int(match.group(2))
    }


async def main():
    parser = argparse.ArgumentParser(description=f"Remote Receiver {RECEIVER_ID}")
    parser.add_argument("--port", help="Serial port for receiver")
    parser.add_argument("--server", required=True, help="Central server URL (e.g., ws://192.168.1.100:8765/data)")
    parser.add_argument("--list-ports", action="store_true", help="List available ports and exit")
    parser.add_argument("--demo", action="store_true", help="Demo mode (no hardware)")
    args = parser.parse_args()
    
    if args.list_ports:
        list_ports()
        return
    
    print("\n" + "=" * 60)
    print(f"REMOTE RECEIVER {RECEIVER_ID}")
    print("=" * 60)
    print(f"  Serial Port: {args.port}")
    print(f"  Server: {args.server}")
    print("=" * 60 + "\n")
    
    # Open serial port
    ser = None
    if not args.demo:
        try:
            ser = serial.Serial(args.port, 115200, timeout=1)
            configure_radio(ser)
        except Exception as e:
            log(f"ERROR: Cannot open {args.port}: {e}")
            list_ports()
            return
    else:
        log("DEMO MODE - generating fake data")
    
    start_time = time.time()
    readings_sent = 0
    reconnect_delay = 2
    running = True
    
    while running:
        try:
            log(f"Connecting to {args.server}...")
            
            async with websockets.connect(args.server, ping_interval=20) as ws:
                log("Connected to central server!")
                
                # Wait for welcome message
                try:
                    welcome = await asyncio.wait_for(ws.recv(), timeout=5)
                    data = json.loads(welcome)
                    if data.get("type") == "connected":
                        log(f"Server: {data.get('message', 'Connected')}")
                except:
                    pass
                
                print("-" * 60)
                reconnect_delay = 2  # Reset on success
                
                # Main loop - read serial and send to server
                loop = asyncio.get_event_loop()
                
                while running:
                    try:
                        if args.demo:
                            # Demo mode
                            await asyncio.sleep(1.5)
                            import random
                            data = {
                                "timestamp": datetime.now().isoformat(),
                                "timestamp_s": round(time.time() - start_time, 3),
                                "receiver_id": RECEIVER_ID,
                                "rssi": random.randint(-70, -40),
                                "snr": random.randint(5, 15)
                            }
                        else:
                            # Real serial read
                            line = await loop.run_in_executor(
                                None,
                                lambda: ser.readline().decode('utf-8', errors='replace').strip()
                            )
                            
                            if not line:
                                continue
                            
                            data = parse_lora_line(line, start_time)
                            if not data:
                                continue
                        
                        # Send to server
                        await ws.send(json.dumps(data))
                        readings_sent += 1
                        
                        # Local display
                        print(f"  RX_{RECEIVER_ID}: {data['timestamp_s']:8.3f}s | "
                              f"RSSI: {data['rssi']:4} dBm | SNR: {data['snr']:3} dB | "
                              f"[sent #{readings_sent}]")
                        
                    except websockets.exceptions.ConnectionClosed:
                        raise
                    except Exception as e:
                        log(f"Error: {e}")
                        await asyncio.sleep(0.1)
                        
        except websockets.exceptions.ConnectionClosed as e:
            log(f"Connection closed: {e}")
        except ConnectionRefusedError:
            log("Connection refused - is the central server running?")
        except Exception as e:
            log(f"Connection error: {e}")
        
        if running:
            log(f"Reconnecting in {reconnect_delay}s...")
            await asyncio.sleep(reconnect_delay)
            reconnect_delay = min(reconnect_delay * 2, 30)
    
    # Cleanup
    if ser and ser.is_open:
        ser.close()
    
    print(f"\nTotal readings sent: {readings_sent}")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nStopped by user")
