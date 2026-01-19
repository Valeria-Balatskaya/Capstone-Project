#!/usr/bin/env python3
"""
Central Server: Receiver A + WebSocket Server
==============================================
Runs on server machine with 1 receiver board connected (optional).
- Reads LoRa data from local receiver (Receiver A, if present)
- Runs WebSocket server to receive data from remote receivers (B, C, etc.)
- Aggregates ALL data and saves to CSV
- Provides dashboard endpoint

Setup:
    1. Connect receiver board via USB (optional)
    2. Find port: python -c "from serial.tools import list_ports; [print(p.device) for p in list_ports.comports()]"
    3. Run: python server.py --port <PORT>

Remote clients connect to: ws://SERVER_IP:8765/data
"""

import asyncio
import argparse
import csv
import json
import random
import re
import signal
import sys
import time
from datetime import datetime
from typing import Set, Optional, Dict

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial")
    sys.exit(1)

try:
    import websockets
    from websockets.server import serve
except ImportError:
    print("ERROR: websockets not installed. Run: pip install websockets")
    sys.exit(1)


# Global state
dashboard_clients: Set = set()
data_clients: Set = set()      # Remote receivers send data here
running = True
start_time = None

# CSV for aggregated data from all receivers
csv_writer = None
csv_file = None

# Local receiver
local_serial: Optional[serial.Serial] = None
LOCAL_RECEIVER_ID = "A"

# Pattern for LoRa output
RSSI_PATTERN = re.compile(r"RssiValue=(-?\d+)\s*dBm,\s*SnrValue=(-?\d+)dB")

# Stats
stats = {"A": 0, "B": 0, "C": 0}


def log(message: str):
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] {message}")


def setup_csv(output_path: str):
    global csv_writer, csv_file
    csv_file = open(output_path, "w", newline="")
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(["timestamp_s", "receiver_id", "rssi_dbm", "snr_db"])
    log(f"CSV: {output_path}")


def write_csv(data: dict):
    if csv_writer:
        csv_writer.writerow([
            data.get("timestamp_s", 0),
            data.get("receiver_id", "?"),
            data.get("rssi", 0),
            data.get("snr", 0)
        ])
        csv_file.flush()


def parse_lora_line(line: str) -> Optional[dict]:
    """Parse LoRa output from local receiver."""
    match = RSSI_PATTERN.search(line)
    if not match:
        return None
    
    rssi = int(match.group(1))
    snr = int(match.group(2))
    elapsed = time.time() - start_time if start_time else 0
    
    return {
        "timestamp": datetime.now().isoformat(),
        "timestamp_s": round(elapsed, 3),
        "receiver_id": LOCAL_RECEIVER_ID,
        "rssi": rssi,
        "snr": snr
    }


def configure_radio(ser: serial.Serial):
    """Configure local receiver radio."""
    log("Configuring local receiver radio...")
    ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
    time.sleep(0.5)
    ser.read_all()
    ser.write(b"AT+TRX=9999\r\n")
    time.sleep(0.5)
    ser.read_all()
    log("Local receiver configured - listening")


async def broadcast_to_dashboard(data: dict):
    """Send data to dashboard clients."""
    if dashboard_clients:
        msg = json.dumps({"type": "reading", "data": data})
        await asyncio.gather(
            *[client.send(msg) for client in dashboard_clients],
            return_exceptions=True
        )


async def handle_reading(data: dict):
    """Process a reading from any receiver (local or remote)."""
    receiver_id = data.get("receiver_id", "?")
    rssi = data.get("rssi", 0)
    snr = data.get("snr", 0)
    timestamp_s = data.get("timestamp_s", 0)
    
    # Update stats
    if receiver_id in stats:
        stats[receiver_id] += 1
    
    # Log
    print(f"  RX_{receiver_id}: {timestamp_s:8.3f}s | RSSI: {rssi:4} dBm | SNR: {snr:3} dB")
    
    # Save to CSV
    write_csv(data)
    
    # Broadcast to dashboard
    await broadcast_to_dashboard(data)


async def websocket_handler(websocket, path):
    """Handle WebSocket connections."""
    client_ip = websocket.remote_address[0] if websocket.remote_address else "unknown"
    
    if path == "/data":
        # This is a remote receiver sending data
        data_clients.add(websocket)
        log(f"Remote receiver connected from {client_ip}")
        
        try:
            # Send welcome
            await websocket.send(json.dumps({
                "type": "connected",
                "message": "Connected to server. Send your readings."
            }))
            
            # Receive data from remote receiver
            async for message in websocket:
                try:
                    data = json.loads(message)
                    await handle_reading(data)
                except json.JSONDecodeError:
                    pass
                    
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            data_clients.discard(websocket)
            log(f"Remote receiver disconnected from {client_ip}")
            
    elif path == "/dashboard":
        # Dashboard viewer
        dashboard_clients.add(websocket)
        log(f"Dashboard connected from {client_ip}")
        
        try:
            await websocket.send(json.dumps({
                "type": "connected",
                "message": "Dashboard connected"
            }))
            await websocket.wait_closed()
        finally:
            dashboard_clients.discard(websocket)
            log(f"Dashboard disconnected")


async def read_local_serial(demo_mode: bool = False):
    """Read from local receiver (A) connected to this server."""
    global running, local_serial
    
    loop = asyncio.get_event_loop()
    
    while running:
        try:
            if demo_mode:
                # Demo mode - generate fake data
                await asyncio.sleep(1.5)
                data = {
                    "timestamp": datetime.now().isoformat(),
                    "timestamp_s": round(time.time() - start_time, 3),
                    "receiver_id": LOCAL_RECEIVER_ID,
                    "rssi": random.randint(-70, -40),
                    "snr": random.randint(5, 15)
                }
                await handle_reading(data)
            else:
                # Real serial read
                if local_serial and local_serial.is_open:
                    line = await loop.run_in_executor(
                        None,
                        lambda: local_serial.readline().decode('utf-8', errors='replace')
                    )
                    
                    if line:
                        line = line.strip()
                        data = parse_lora_line(line)
                        if data:
                            await handle_reading(data)
                else:
                    await asyncio.sleep(1)
                    
        except Exception as e:
            log(f"Serial read error: {e}")
            await asyncio.sleep(1)


def print_stats():
    """Print statistics summary."""
    print("\n" + "=" * 50)
    print("STATISTICS:")
    for rid, count in stats.items():
        print(f"  Receiver {rid}: {count} readings")
    print(f"  Total: {sum(stats.values())} readings")
    print("=" * 50)


async def main():
    global running, start_time, local_serial
    
    parser = argparse.ArgumentParser(description="Central Server: Receiver A + WebSocket Server")
    parser.add_argument("--port", help="Serial port for local receiver A")
    parser.add_argument("--ws-port", type=int, default=8765, help="WebSocket server port")
    parser.add_argument("--output", default="all_receivers.csv", help="Output CSV file")
    parser.add_argument("--demo", action="store_true", help="Demo mode (no hardware)")
    parser.add_argument("--list-ports", action="store_true", help="List available serial ports and exit")
    args = parser.parse_args()
    
    # List ports if requested
    if args.list_ports:
        print("\nAvailable serial ports:")
        ports = serial.tools.list_ports.comports()
        if ports:
            for p in ports:
                print(f"  {p.device}: {p.description}")
        else:
            print("  No serial ports found")
        return
    
    start_time = time.time()
    setup_csv(args.output)
    
    # Setup local serial
    if not args.demo:
        try:
            local_serial = serial.Serial(args.port, 115200, timeout=1)
            configure_radio(local_serial)
            log(f"Local receiver (A) on {args.port}")
        except Exception as e:
            log(f"ERROR: Cannot open {args.port}: {e}")
            log("Use --demo for demo mode or check your port")
            return
    else:
        log("DEMO MODE - generating fake data for receiver A")
    
    # Print server info
    import socket
    hostname = socket.gethostname()
    try:
        local_ip = socket.gethostbyname(hostname)
    except:
        local_ip = "localhost"
    
    print("\n" + "=" * 60)
    print("CENTRAL SERVER RUNNING")
    print("=" * 60)
    print(f"  Local Receiver: A (on {args.port if not args.demo else 'DEMO'})")
    print(f"  WebSocket Server: ws://{local_ip}:{args.ws_port}")
    print(f"  CSV Output: {args.output}")
    print()
    print("  Remote receivers should connect to:")
    print(f"    ws://{local_ip}:{args.ws_port}/data")
    print()
    print("  Dashboard available at:")
    print(f"    Open dashboard.html and connect to ws://{local_ip}:{args.ws_port}/dashboard")
    print("=" * 60)
    print()
    
    # Handle Ctrl+C
    def signal_handler():
        global running
        running = False
        log("Shutting down...")
    
    loop = asyncio.get_event_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, signal_handler)
        except NotImplementedError:
            pass  # Some platforms don't support signals in async
    
    # Start WebSocket server
    async with serve(websocket_handler, "0.0.0.0", args.ws_port):
        log(f"WebSocket server started on port {args.ws_port}")
        
        # Run local serial reader
        try:
            await read_local_serial(demo_mode=args.demo)
        except asyncio.CancelledError:
            pass
    
    # Cleanup
    if local_serial and local_serial.is_open:
        local_serial.close()
    if csv_file:
        csv_file.close()
    
    print_stats()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nStopped by user")
