#!/usr/bin/env python3
"""
Windows Tag (Sender) Script
============================
Runs on Windows laptop with the TAG/sender board connected.
This laptop moves around the room with the tag to test positioning.
Transmits LoRa packets periodically for receivers to pick up.

Setup:
    1. Connect sender board to Windows USB
    2. Find port in Device Manager or run: python -c "from serial.tools import list_ports; [print(p.device) for p in list_ports.comports()]"
    3. Run: python windows_tag.py --port COM5

IMPORTANT: This is the MOBILE unit - walk around with this laptop + tag!
"""

import argparse
import sys
import time

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("ERROR: pyserial not installed. Run: pip install pyserial")
    sys.exit(1)


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


def main():
    parser = argparse.ArgumentParser(description="Windows Tag (Sender) - Transmits LoRa packets")
    parser.add_argument("--port", default="COM5", help="Serial port for tag/sender (default: COM5)")
    parser.add_argument("--packets", type=int, default=10, help="Packets per burst (default: 10)")
    parser.add_argument("--interval", type=float, default=7.0, help="Seconds between bursts (default: 7)")
    parser.add_argument("--list-ports", action="store_true", help="List available ports and exit")
    args = parser.parse_args()
    
    if args.list_ports:
        list_ports()
        return
    
    print("\n" + "=" * 50)
    print("WINDOWS TAG (SENDER) - MOBILE UNIT")
    print("=" * 50)
    print(f"  Port: {args.port}")
    print(f"  Packets per burst: {args.packets}")
    print(f"  Interval: {args.interval} seconds")
    print("=" * 50)
    print("  📍 Move around with this laptop to test positioning!")
    print("=" * 50 + "\n")
    
    try:
        ser = serial.Serial(args.port, 115200, timeout=1)
    except Exception as e:
        print(f"ERROR: Cannot open {args.port}: {e}")
        print("\nAvailable ports:")
        list_ports()
        return
    
    # Reset board
    print("Resetting board...")
    ser.write(b"ATZ\r\n")
    time.sleep(1)
    response = ser.read_all().decode(errors="ignore")
    print(f"  Response: {response.strip()}")
    
    # Configure radio (MUST match receiver config!)
    print("Configuring radio...")
    ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
    time.sleep(0.5)
    response = ser.read_all().decode(errors="ignore")
    print(f"  Response: {response.strip()}")
    
    print("\n" + "-" * 50)
    print("Transmitting packets... Press Ctrl+C to stop")
    print("-" * 50 + "\n")
    
    burst_count = 0
    try:
        while True:
            burst_count += 1
            print(f"[Burst {burst_count}] Sending {args.packets} packets...")
            
            ser.write(f"AT+TTX={args.packets}\r\n".encode())
            time.sleep(args.packets * 0.3 + 1)  # Wait for TX to complete
            
            response = ser.read_all().decode(errors="ignore")
            if response.strip():
                # Parse response for TX success
                lines = response.strip().split('\n')
                for line in lines:
                    if line.strip():
                        print(f"  {line.strip()}")
            
            print(f"  Waiting {args.interval}s before next burst...\n")
            time.sleep(args.interval - (args.packets * 0.3 + 1))
            
    except KeyboardInterrupt:
        print("\n\nStopping...")
    finally:
        ser.close()
        print(f"Total bursts sent: {burst_count}")


if __name__ == "__main__":
    main()
