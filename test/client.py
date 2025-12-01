#!/usr/bin/env python3
"""
TEST: Windows WebSocket Client
==============================
Connects to the Mac receiver server and displays incoming LoRa data.

Usage:
    python client.py --server ws://192.168.1.100:8765/data
    python client.py --server ws://MAC_IP:8765/data --output readings.csv
"""

import asyncio
import argparse
import json
import csv
import sys
from datetime import datetime
from pathlib import Path

try:
    import websockets
except ImportError:
    print("ERROR: websockets not installed. Run: pip install websockets")
    sys.exit(1)


class LoRaClient:
    def __init__(self, server_url: str, output_file: str = None, verbose: bool = False):
        self.server_url = server_url
        self.output_file = output_file
        self.verbose = verbose
        self.running = True
        self.reconnect_delay = 2
        self.max_reconnect_delay = 30
        self.readings_count = 0
        self.csv_writer = None
        self.csv_file = None
        
    def log(self, message: str, level: str = "INFO"):
        """Print timestamped log message."""
        timestamp = datetime.now().strftime("%H:%M:%S")
        if level == "ERROR":
            print(f"[{timestamp}] ERROR: {message}")
        elif level == "WARN":
            print(f"[{timestamp}] WARN: {message}")
        elif self.verbose or level == "INFO":
            print(f"[{timestamp}] {message}")
    
    def setup_csv(self):
        """Setup CSV output file if specified."""
        if not self.output_file:
            return
        
        file_exists = Path(self.output_file).exists()
        self.csv_file = open(self.output_file, 'a', newline='', encoding='utf-8')
        self.csv_writer = csv.writer(self.csv_file)
        
        if not file_exists:
            self.csv_writer.writerow(['timestamp_s', 'receiver_id', 'rssi_dbm', 'snr_db'])
            self.csv_file.flush()
            self.log(f"Created CSV file: {self.output_file}")
        else:
            self.log(f"Appending to CSV file: {self.output_file}")
    
    def write_csv(self, data: dict):
        """Write reading to CSV file."""
        if self.csv_writer:
            self.csv_writer.writerow([
                data.get('timestamp_s', ''),
                data.get('receiver_id', ''),
                data.get('rssi', ''),
                data.get('snr', '')
            ])
            self.csv_file.flush()
    
    def display_reading(self, data: dict):
        """Display a reading in a nice format."""
        timestamp_s = data.get('timestamp_s', 0)
        receiver_id = data.get('receiver_id', '?')
        rssi = data.get('rssi', 0)
        snr = data.get('snr', 0)
        
        # Color coding based on RSSI
        if rssi >= -50:
            signal = "████ Excellent"
        elif rssi >= -60:
            signal = "███░ Good"
        elif rssi >= -70:
            signal = "██░░ Fair"
        elif rssi >= -80:
            signal = "█░░░ Weak"
        else:
            signal = "░░░░ Poor"
        
        print(f"RX_{receiver_id}: {timestamp_s:8.3f}s | RSSI: {rssi:4} dBm | SNR: {snr:3} dB | {signal}")
        self.readings_count += 1
    
    async def connect_and_listen(self):
        """Connect to server and listen for data."""
        current_delay = self.reconnect_delay
        
        while self.running:
            try:
                self.log(f"Connecting to {self.server_url}...")
                
                async with websockets.connect(
                    self.server_url,
                    ping_interval=20,
                    ping_timeout=10
                ) as websocket:
                    self.log("Connected! Waiting for data...")
                    print("-" * 60)
                    current_delay = self.reconnect_delay  # Reset delay on success
                    
                    async for message in websocket:
                        try:
                            data = json.loads(message)
                            
                            # Handle dashboard format (wrapped in type/data)
                            if isinstance(data, dict) and data.get('type') == 'reading':
                                data = data.get('data', {})
                            elif isinstance(data, dict) and data.get('type') == 'connected':
                                self.log(f"Server: {data.get('message', 'Connected')}")
                                continue
                            
                            # Display and optionally save
                            if 'receiver_id' in data or 'rssi' in data:
                                self.display_reading(data)
                                self.write_csv(data)
                            elif self.verbose:
                                self.log(f"Received: {data}")
                                
                        except json.JSONDecodeError:
                            if self.verbose:
                                self.log(f"Non-JSON message: {message[:100]}")
                                
            except websockets.exceptions.ConnectionClosed as e:
                self.log(f"Connection closed: {e}", "WARN")
            except ConnectionRefusedError:
                self.log(f"Connection refused - is the server running?", "ERROR")
            except Exception as e:
                self.log(f"Connection error: {e}", "ERROR")
            
            if self.running:
                self.log(f"Reconnecting in {current_delay} seconds...")
                await asyncio.sleep(current_delay)
                current_delay = min(current_delay * 2, self.max_reconnect_delay)
    
    def stop(self):
        """Stop the client."""
        self.running = False
        if self.csv_file:
            self.csv_file.close()
    
    async def run(self):
        """Main run loop."""
        self.setup_csv()
        
        try:
            await self.connect_and_listen()
        finally:
            self.stop()
            print("-" * 60)
            self.log(f"Total readings received: {self.readings_count}")


def main():
    parser = argparse.ArgumentParser(
        description="Windows WebSocket Client for LoRa Data",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python client.py --server ws://192.168.1.100:8765/data
    python client.py --server ws://MAC_IP:8765/data --output readings.csv
    python client.py --server ws://localhost:8765/data --verbose
        """
    )
    parser.add_argument(
        "--server", "-s",
        required=True,
        help="WebSocket server URL (e.g., ws://192.168.1.100:8765/data)"
    )
    parser.add_argument(
        "--output", "-o",
        help="Optional CSV file to save readings"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show verbose output"
    )
    
    args = parser.parse_args()
    
    print("=" * 60)
    print("  LoRa WebSocket Client")
    print("=" * 60)
    print(f"  Server: {args.server}")
    if args.output:
        print(f"  Output: {args.output}")
    print("  Press Ctrl+C to stop")
    print("=" * 60)
    print()
    
    client = LoRaClient(
        server_url=args.server,
        output_file=args.output,
        verbose=args.verbose
    )
    
    try:
        asyncio.run(client.run())
    except KeyboardInterrupt:
        print("\nStopped by user.")


if __name__ == "__main__":
    main()
