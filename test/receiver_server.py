#!/usr/bin/env python3
"""
LoRa Receiver + WebSocket Server
=================================
Runs on Mac with receiver board connected via USB.
- Configures radio with AT+TCONF and AT+TRX commands
- Parses "RssiValue=-45 dBm, SnrValue=12dB" format
- Streams data via WebSocket to remote clients
- Also saves to local CSV file

Usage:
    python receiver_server.py --port /dev/cu.usbserial-1110
    python receiver_server.py --port /dev/cu.usbserial-1110 --receiver-id B
"""

import asyncio
import argparse
import csv
import json
import os
import re
import signal
import sys
import time
from datetime import datetime
from typing import Set, Optional

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
serial_port: Optional[serial.Serial] = None
running = True
start_time = None
csv_writer = None
csv_file = None
receiver_id = "A"

# Pattern matching your actual LoRa output format
# Example: "RssiValue=-45 dBm, SnrValue=12dB"
RSSI_PATTERN = re.compile(r"RssiValue=(-?\d+)\s*dBm,\s*SnrValue=(-?\d+)dB")


def parse_lora_packet(line: str) -> Optional[dict]:
    """
    Parse LoRa packet from your board's format.
    
    Expected format: RssiValue=-45 dBm, SnrValue=12dB
    """
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
        "snr": snr,
        "raw_line": line
    }


def log(message: str):
    """Print timestamped log message."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")


def setup_csv(output_path: str):
    """Setup CSV file for local logging."""
    global csv_writer, csv_file
    csv_file = open(output_path, "w", newline="")
    csv_writer = csv.writer(csv_file)
    csv_writer.writerow(["timestamp_s", "rssi_dbm", "snr_db"])
    log(f"CSV logging to: {output_path}")


def write_csv(data: dict):
    """Write reading to local CSV file."""
    global csv_writer, csv_file
    if csv_writer:
        csv_writer.writerow([data["timestamp_s"], data["rssi"], data["snr"]])
        csv_file.flush()


async def broadcast_to_clients(data: dict):
    """Send data to all connected clients."""
    message = json.dumps(data)
    
    # Send to data clients
    if data_clients:
        await asyncio.gather(
            *[client.send(message) for client in data_clients],
            return_exceptions=True
        )
    
    # Send to dashboard clients (wrap in dashboard format)
    if dashboard_clients:
        dashboard_msg = json.dumps({
            "type": "reading",
            "data": data
        })
        await asyncio.gather(
            *[client.send(dashboard_msg) for client in dashboard_clients],
            return_exceptions=True
        )


def configure_radio(ser: serial.Serial):
    """Configure radio with AT commands (same as your auto_rx scripts)."""
    log("Configuring radio...")
    
    # Configure radio: AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0
    ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
    time.sleep(0.5)
    response = ser.read_all().decode(errors="ignore")
    if response.strip():
        log(f"TCONF response: {response.strip()}")
    
    # Start receiving: AT+TRX=9999 (receive up to 9999 packets)
    ser.write(b"AT+TRX=9999\r\n")
    time.sleep(0.5)
    response = ser.read_all().decode(errors="ignore")
    if response.strip():
        log(f"TRX response: {response.strip()}")
    
    log("Radio configured - listening for packets")


async def serial_reader():
    """Read from serial port and broadcast to clients."""
    global serial_port, running, start_time
    
    loop = asyncio.get_event_loop()
    start_time = time.time()
    
    while running:
        try:
            if serial_port is None or not serial_port.is_open:
                await asyncio.sleep(1)
                continue
            
            # Read line in executor to not block
            line = await loop.run_in_executor(
                None, 
                lambda: serial_port.readline().decode('utf-8', errors='replace')
            )
            
            if not line:
                continue
            
            line = line.strip()
            if not line:
                continue
            
            # Parse LoRa packet
            data = parse_lora_packet(line)
            if data:
                elapsed = data["timestamp_s"]
                rssi = data["rssi"]
                snr = data["snr"]
                log(f"RX_{receiver_id}: {elapsed:.3f}s  RSSI={rssi} dBm  SNR={snr} dB")
                
                # Save to local CSV
                write_csv(data)
                
                # Broadcast to WebSocket clients
                await broadcast_to_clients(data)
            else:
                # Log other serial output for debugging
                if line and not line.startswith("AT") and "OK" not in line:
                    log(f"Serial: {line}")
                    
        except serial.SerialException as e:
            log(f"Serial error: {e}")
            await asyncio.sleep(2)
        except Exception as e:
            log(f"Reader error: {e}")
            await asyncio.sleep(1)


async def handle_websocket(websocket, path):
    """Handle incoming WebSocket connections."""
    client_ip = websocket.remote_address[0] if websocket.remote_address else "unknown"
    
    if path == "/dashboard":
        dashboard_clients.add(websocket)
        log(f"Dashboard client connected from {client_ip}")
        try:
            # Send welcome message
            await websocket.send(json.dumps({
                "type": "connected",
                "message": f"Connected to LoRa Receiver {receiver_id}",
                "receiver_id": receiver_id,
                "server_time": datetime.now().isoformat()
            }))
            # Keep connection alive
            async for message in websocket:
                pass  # Dashboard doesn't send data, just receives
        finally:
            dashboard_clients.discard(websocket)
            log(f"Dashboard client disconnected: {client_ip}")
    
    elif path == "/data":
        data_clients.add(websocket)
        log(f"Data client connected from {client_ip}")
        try:
            # Keep connection alive
            async for message in websocket:
                pass  # Data clients just receive
        finally:
            data_clients.discard(websocket)
            log(f"Data client disconnected: {client_ip}")
    
    else:
        # Default to data endpoint
        data_clients.add(websocket)
        log(f"Client connected from {client_ip} (path: {path})")
        try:
            async for message in websocket:
                pass
        finally:
            data_clients.discard(websocket)
            log(f"Client disconnected: {client_ip}")


def list_serial_ports():
    """List available serial ports."""
    ports = serial.tools.list_ports.comports()
    print("\nAvailable serial ports:")
    print("-" * 50)
    for port in ports:
        print(f"  {port.device}")
        print(f"    Description: {port.description}")
        if port.manufacturer:
            print(f"    Manufacturer: {port.manufacturer}")
        print()
    if not ports:
        print("  No serial ports found!")
    print()


def open_serial(port: str, baud: int) -> Optional[serial.Serial]:
    """Open serial port with error handling."""
    try:
        ser = serial.Serial(
            port=port,
            baudrate=baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=1
        )
        log(f"Serial port {port} opened at {baud} baud")
        return ser
    except serial.SerialException as e:
        log(f"Failed to open serial port: {e}")
        return None


async def main():
    global serial_port, running, receiver_id, csv_file
    
    parser = argparse.ArgumentParser(
        description="LoRa Receiver + WebSocket Server",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python receiver_server.py --port /dev/cu.usbserial-1110 --receiver-id B
    python receiver_server.py --port /dev/cu.usbserial-1120 --receiver-id C
    python receiver_server.py --list
    python receiver_server.py --demo --receiver-id TEST
        """
    )
    parser.add_argument(
        "--port", "-p",
        help="Serial port for receiver board (e.g., /dev/cu.usbserial-1110)"
    )
    parser.add_argument(
        "--baud", "-b",
        type=int,
        default=115200,
        help="Baud rate (default: 115200)"
    )
    parser.add_argument(
        "--receiver-id", "-r",
        default="A",
        help="Receiver identifier: A, B, C, etc. (default: A)"
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
        "--output", "-o",
        help="CSV output file (default: rx_<receiver_id>.csv)"
    )
    parser.add_argument(
        "--list", "-l",
        action="store_true",
        help="List available serial ports and exit"
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Run in demo mode (generate fake data, no serial required)"
    )
    
    args = parser.parse_args()
    receiver_id = args.receiver_id
    
    receiver_id = args.receiver_id
    
    if args.list:
        list_serial_ports()
        return
    
    # Setup CSV output
    csv_path = args.output or f"rx_{receiver_id}.csv"
    setup_csv(csv_path)
    
    # Demo mode for testing without hardware
    if args.demo:
        log(f"Starting in DEMO mode as Receiver {receiver_id}")
        
        async def demo_data_generator():
            """Generate fake data for testing."""
            import random
            global start_time
            start_time = time.time()
            while running:
                await asyncio.sleep(2)
                elapsed = time.time() - start_time
                fake_data = {
                    "timestamp": datetime.now().isoformat(),
                    "timestamp_s": round(elapsed, 3),
                    "receiver_id": receiver_id,
                    "rssi": random.randint(-80, -30),
                    "snr": random.randint(5, 15),
                    "raw_line": "DEMO"
                }
                log(f"DEMO RX_{receiver_id}: {elapsed:.3f}s  RSSI={fake_data['rssi']} dBm  SNR={fake_data['snr']} dB")
                write_csv(fake_data)
                await broadcast_to_clients(fake_data)
        
        # Start WebSocket server
        async with serve(handle_websocket, args.host, args.ws_port):
            log(f"WebSocket server started on ws://{args.host}:{args.ws_port}")
            log("Endpoints: /data (raw JSON), /dashboard (for HTML dashboard)")
            log("Press Ctrl+C to stop")
            
            await demo_data_generator()
        return
    
    # Normal mode - require serial port
    if not args.port:
        print("ERROR: Serial port required. Use --port or --list to see available ports.")
        print("       Or use --demo to test without hardware.")
        list_serial_ports()
        sys.exit(1)
    
    # Open serial port
    serial_port = open_serial(args.port, args.baud)
    if not serial_port:
        sys.exit(1)
    
    # Configure the radio with AT commands
    configure_radio(serial_port)
    
    # Handle shutdown gracefully
    def shutdown_handler(sig, frame):
        global running
        log("Shutting down...")
        running = False
    
    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)
    
    try:
        # Start WebSocket server
        async with serve(handle_websocket, args.host, args.ws_port):
            log(f"WebSocket server started on ws://{args.host}:{args.ws_port}")
            log(f"Receiver ID: {receiver_id}")
            log("Endpoints:")
            log("  /data      - Raw JSON data stream")
            log("  /dashboard - For HTML dashboard clients")
            log("Press Ctrl+C to stop")
            
            # Run serial reader
            await serial_reader()
            
    finally:
        if serial_port and serial_port.is_open:
            serial_port.close()
            log("Serial port closed")
        if csv_file:
            csv_file.close()
            log("CSV file closed")


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nStopped.")
