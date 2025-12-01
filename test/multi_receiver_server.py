#!/usr/bin/env python3
"""
Multi-Receiver WebSocket Server
================================
Runs on Mac with MULTIPLE receiver boards connected via USB.
- Configures all radios with AT+TCONF and AT+TRX commands
- Parses "RssiValue=-45 dBm, SnrValue=12dB" format from each receiver
- Streams ALL data via single WebSocket server
- Saves to separate CSV files per receiver

Usage:
    python multi_receiver_server.py --ports /dev/cu.usbserial-1110,/dev/cu.usbserial-1120,/dev/cu.usbserial-1130
    python multi_receiver_server.py --ports /dev/cu.usbserial-1110,/dev/cu.usbserial-1120,/dev/cu.usbserial-1130 --ids B,C,D
"""

import asyncio
import argparse
import csv
import json
import re
import signal
import sys
import time
from datetime import datetime
from typing import Set, Optional, Dict, List

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
data_clients: Set = set()
running = True
start_time = None

# Per-receiver state
receivers: Dict[str, dict] = {}  # receiver_id -> {serial, csv_writer, csv_file}

# Pattern matching your LoRa output format
RSSI_PATTERN = re.compile(r"RssiValue=(-?\d+)\s*dBm,\s*SnrValue=(-?\d+)dB")


def parse_lora_packet(line: str, receiver_id: str) -> Optional[dict]:
    """Parse LoRa packet from board's format."""
    match = RSSI_PATTERN.search(line)
    if not match:
        return None
    
    rssi = int(match.group(1))
    snr = int(match.group(2))
    elapsed = time.time() - start_time if start_time else 0
    
    return {
        "timestamp": datetime.now().isoformat(),
        "timestamp_s": round(elapsed, 3),
        "receiver_id": receiver_id,
        "rssi": rssi,
        "snr": snr
    }


def log(message: str):
    """Print timestamped log message."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")


def setup_csv(receiver_id: str, output_dir: str = ".") -> tuple:
    """Setup CSV file for a receiver."""
    csv_path = f"{output_dir}/rx_{receiver_id}.csv"
    csv_file = open(csv_path, "w", newline="")
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(["timestamp_s", "rssi_dbm", "snr_db"])
    log(f"Receiver {receiver_id}: CSV logging to {csv_path}")
    return csv_writer, csv_file


def write_csv(receiver_id: str, data: dict):
    """Write reading to receiver's CSV file."""
    if receiver_id in receivers and receivers[receiver_id].get('csv_writer'):
        writer = receivers[receiver_id]['csv_writer']
        csv_file = receivers[receiver_id]['csv_file']
        writer.writerow([data["timestamp_s"], data["rssi"], data["snr"]])
        csv_file.flush()


async def broadcast_to_clients(data: dict):
    """Send data to all connected WebSocket clients."""
    message = json.dumps(data)
    
    if data_clients:
        await asyncio.gather(
            *[client.send(message) for client in data_clients],
            return_exceptions=True
        )
    
    if dashboard_clients:
        dashboard_msg = json.dumps({"type": "reading", "data": data})
        await asyncio.gather(
            *[client.send(dashboard_msg) for client in dashboard_clients],
            return_exceptions=True
        )


def configure_radio(ser: serial.Serial, receiver_id: str):
    """Configure radio with AT commands."""
    log(f"Receiver {receiver_id}: Configuring radio...")
    
    ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
    time.sleep(0.5)
    ser.read_all()
    
    ser.write(b"AT+TRX=9999\r\n")
    time.sleep(0.5)
    ser.read_all()
    
    log(f"Receiver {receiver_id}: Radio configured - listening")


async def read_serial(receiver_id: str):
    """Read from one serial port and broadcast."""
    global running
    
    ser = receivers[receiver_id]['serial']
    loop = asyncio.get_event_loop()
    
    while running:
        try:
            if ser is None or not ser.is_open:
                await asyncio.sleep(1)
                continue
            
            line = await loop.run_in_executor(
                None,
                lambda: ser.readline().decode('utf-8', errors='replace')
            )
            
            if not line:
                continue
            
            line = line.strip()
            if not line:
                continue
            
            data = parse_lora_packet(line, receiver_id)
            if data:
                log(f"RX_{receiver_id}: {data['timestamp_s']:.3f}s  RSSI={data['rssi']} dBm  SNR={data['snr']} dB")
                write_csv(receiver_id, data)
                await broadcast_to_clients(data)
            elif "OK" not in line and not line.startswith("AT"):
                log(f"RX_{receiver_id} Serial: {line}")
                
        except serial.SerialException as e:
            log(f"RX_{receiver_id} Serial error: {e}")
            await asyncio.sleep(2)
        except Exception as e:
            log(f"RX_{receiver_id} Error: {e}")
            await asyncio.sleep(1)


async def handle_websocket(websocket, path):
    """Handle incoming WebSocket connections."""
    client_ip = websocket.remote_address[0] if websocket.remote_address else "unknown"
    
    if path == "/dashboard":
        dashboard_clients.add(websocket)
        log(f"Dashboard client connected from {client_ip}")
        try:
            await websocket.send(json.dumps({
                "type": "connected",
                "message": f"Connected to Multi-Receiver Server",
                "receivers": list(receivers.keys()),
                "server_time": datetime.now().isoformat()
            }))
            async for message in websocket:
                pass
        finally:
            dashboard_clients.discard(websocket)
            log(f"Dashboard client disconnected: {client_ip}")
    else:
        data_clients.add(websocket)
        log(f"Data client connected from {client_ip}")
        try:
            async for message in websocket:
                pass
        finally:
            data_clients.discard(websocket)
            log(f"Data client disconnected: {client_ip}")


def list_serial_ports():
    """List available serial ports."""
    ports = serial.tools.list_ports.comports()
    print("\nAvailable serial ports:")
    print("-" * 50)
    for port in ports:
        print(f"  {port.device}")
        print(f"    Description: {port.description}")
    if not ports:
        print("  No serial ports found!")
    print()


def open_serial(port: str, baud: int) -> Optional[serial.Serial]:
    """Open serial port."""
    try:
        ser = serial.Serial(
            port=port,
            baudrate=baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )
        return ser
    except serial.SerialException as e:
        log(f"Failed to open {port}: {e}")
        return None


async def main():
    global running, start_time, receivers
    
    parser = argparse.ArgumentParser(
        description="Multi-Receiver LoRa WebSocket Server",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # 3 receivers:
    python multi_receiver_server.py --ports /dev/cu.usbserial-1110,/dev/cu.usbserial-1120,/dev/cu.usbserial-1130
    
    # With custom IDs:
    python multi_receiver_server.py --ports /dev/cu.usbserial-1110,/dev/cu.usbserial-1120,/dev/cu.usbserial-1130 --ids B,C,D
    
    # List ports:
    python multi_receiver_server.py --list
    
    # Demo mode (no hardware):
    python multi_receiver_server.py --demo
        """
    )
    parser.add_argument(
        "--ports", "-p",
        help="Comma-separated list of serial ports (e.g., /dev/cu.usbserial-1110,/dev/cu.usbserial-1120,/dev/cu.usbserial-1130)"
    )
    parser.add_argument(
        "--ids", "-i",
        default="B,C,D",
        help="Comma-separated receiver IDs (default: B,C,D)"
    )
    parser.add_argument(
        "--baud", "-b",
        type=int,
        default=115200,
        help="Baud rate (default: 115200)"
    )
    parser.add_argument(
        "--host",
        default="0.0.0.0",
        help="WebSocket server host (default: 0.0.0.0)"
    )
    parser.add_argument(
        "--ws-port",
        type=int,
        default=8765,
        help="WebSocket server port (default: 8765)"
    )
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List available serial ports and exit"
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Run in demo mode with 3 fake receivers"
    )
    
    args = parser.parse_args()
    
    if args.list:
        list_serial_ports()
        return
    
    start_time = time.time()
    receiver_ids = [x.strip() for x in args.ids.split(",")]
    
    # Demo mode
    if args.demo:
        log("Starting in DEMO mode with 3 fake receivers")
        
        for rid in receiver_ids[:3]:
            csv_writer, csv_file = setup_csv(rid)
            receivers[rid] = {'serial': None, 'csv_writer': csv_writer, 'csv_file': csv_file}
        
        async def demo_generator():
            import random
            while running:
                await asyncio.sleep(1.3)
                for rid in receivers.keys():
                    elapsed = time.time() - start_time
                    data = {
                        "timestamp": datetime.now().isoformat(),
                        "timestamp_s": round(elapsed, 3),
                        "receiver_id": rid,
                        "rssi": random.randint(-80, -30),
                        "snr": random.randint(8, 15)
                    }
                    log(f"DEMO RX_{rid}: {elapsed:.3f}s  RSSI={data['rssi']} dBm  SNR={data['snr']} dB")
                    write_csv(rid, data)
                    await broadcast_to_clients(data)
                    await asyncio.sleep(0.1)  # Small delay between receivers
        
        async with serve(handle_websocket, args.host, args.ws_port):
            log(f"WebSocket server started on ws://{args.host}:{args.ws_port}")
            log(f"Receivers: {', '.join(receivers.keys())}")
            log("Press Ctrl+C to stop")
            await demo_generator()
        return
    
    # Real mode
    if not args.ports:
        print("ERROR: --ports required. Use --list to see available ports.")
        print("       Or use --demo to test without hardware.")
        list_serial_ports()
        sys.exit(1)
    
    ports = [x.strip() for x in args.ports.split(",")]
    
    if len(ports) != len(receiver_ids):
        print(f"ERROR: Number of ports ({len(ports)}) must match number of IDs ({len(receiver_ids)})")
        print(f"       Ports: {ports}")
        print(f"       IDs: {receiver_ids}")
        sys.exit(1)
    
    # Open all serial ports and configure radios
    for port, rid in zip(ports, receiver_ids):
        ser = open_serial(port, args.baud)
        if not ser:
            log(f"WARNING: Could not open {port} for receiver {rid}")
            continue
        
        log(f"Receiver {rid}: Opened {port}")
        configure_radio(ser, rid)
        
        csv_writer, csv_file = setup_csv(rid)
        receivers[rid] = {'serial': ser, 'csv_writer': csv_writer, 'csv_file': csv_file}
    
    if not receivers:
        print("ERROR: No receivers could be initialized!")
        sys.exit(1)
    
    # Handle shutdown
    def shutdown_handler(sig, frame):
        global running
        log("Shutting down...")
        running = False
    
    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)
    
    try:
        async with serve(handle_websocket, args.host, args.ws_port):
            log(f"WebSocket server started on ws://{args.host}:{args.ws_port}")
            log(f"Active receivers: {', '.join(receivers.keys())}")
            log("Endpoints: /data (raw JSON), /dashboard (for HTML)")
            log("Press Ctrl+C to stop")
            
            # Start all serial readers concurrently
            tasks = [read_serial(rid) for rid in receivers.keys()]
            await asyncio.gather(*tasks)
            
    finally:
        for rid, r in receivers.items():
            if r.get('serial') and r['serial'].is_open:
                r['serial'].close()
                log(f"Receiver {rid}: Serial closed")
            if r.get('csv_file'):
                r['csv_file'].close()
                log(f"Receiver {rid}: CSV closed")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nStopped.")
