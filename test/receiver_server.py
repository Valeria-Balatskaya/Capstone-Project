#!/usr/bin/env python3
"""
TEST: Mac Receiver + WebSocket Server
======================================
Runs on Mac laptop with receiver board connected via USB.
- Reads LoRa packets from serial port
- Runs WebSocket server for remote clients
- Serves dashboard endpoint for browser viewing

Usage:
    python receiver_server.py --port /dev/cu.usbserial-XXXX
    python receiver_server.py --port /dev/cu.usbmodem-XXXX --baud 9600
"""

import asyncio
import argparse
import json
import re
import signal
import sys
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


def parse_lora_packet(line: str) -> Optional[dict]:
    """
    Parse LoRa packet from Wio-E5 format.
    
    Expected format: +RX "HEXDATA",-45,12
    Where HEXDATA contains the tag ID as hex-encoded string.
    """
    # Pattern: +RX "hex_data",rssi,snr
    match = re.match(r'\+RX\s+"([0-9A-Fa-f]+)",(-?\d+),(\d+)', line.strip())
    if not match:
        return None
    
    hex_payload = match.group(1)
    rssi = int(match.group(2))
    snr = int(match.group(3))
    
    # Try to decode hex payload as ASCII (tag ID)
    try:
        tag_id = bytes.fromhex(hex_payload).decode('ascii', errors='replace')
        # Clean up non-printable characters
        tag_id = ''.join(c if c.isprintable() else '' for c in tag_id).strip()
        if not tag_id:
            tag_id = f"TAG_{hex_payload[:8]}"
    except Exception:
        tag_id = f"TAG_{hex_payload[:8]}"
    
    return {
        "timestamp": datetime.now().isoformat(),
        "tag_id": tag_id,
        "rssi": rssi,
        "snr": snr,
        "raw_payload": hex_payload
    }


def log(message: str):
    """Print timestamped log message."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] {message}")


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


async def serial_reader():
    """Read from serial port and broadcast to clients."""
    global serial_port, running
    
    loop = asyncio.get_event_loop()
    
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
                log(f"RX: tag={data['tag_id']}, rssi={data['rssi']}, snr={data['snr']}")
                await broadcast_to_clients(data)
            else:
                # Log other serial output for debugging
                if line and not line.startswith("AT"):
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
                "message": "Connected to LoRa receiver server",
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
    global serial_port, running
    
    parser = argparse.ArgumentParser(
        description="LoRa Receiver + WebSocket Server for Mac",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python receiver_server.py --port /dev/cu.usbserial-1420
    python receiver_server.py --port /dev/cu.usbmodem14201 --baud 9600
    python receiver_server.py --list
        """
    )
    parser.add_argument(
        "--port", "-p",
        help="Serial port for receiver board (e.g., /dev/cu.usbserial-1420)"
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
        help="Run in demo mode (generate fake data, no serial required)"
    )
    
    args = parser.parse_args()
    
    if args.list:
        list_serial_ports()
        return
    
    # Demo mode for testing without hardware
    if args.demo:
        log("Starting in DEMO mode (no serial port required)")
        
        async def demo_data_generator():
            """Generate fake data for testing."""
            import random
            while running:
                await asyncio.sleep(2)
                fake_data = {
                    "timestamp": datetime.now().isoformat(),
                    "tag_id": f"TAG{random.randint(1, 3):03d}",
                    "rssi": random.randint(-80, -30),
                    "snr": random.randint(5, 15),
                    "raw_payload": "44454D4F"  # "DEMO" in hex
                }
                log(f"DEMO: tag={fake_data['tag_id']}, rssi={fake_data['rssi']}")
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


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nStopped.")
