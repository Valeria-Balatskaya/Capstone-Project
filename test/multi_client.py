#!/usr/bin/env python3
"""
Multi-Receiver WebSocket Client
================================
Connects to Mac multi-receiver server and saves data from ALL receivers.
Creates separate CSV files for each receiver.

Usage:
    python multi_client.py --server ws://172.20.10.2:8765/data
    python multi_client.py --server ws://MAC_IP:8765/data --output-dir ./data
"""

import asyncio
import argparse
import csv
import json
import sys
from datetime import datetime
from pathlib import Path
from typing import Dict

try:
    import websockets
except ImportError:
    print("ERROR: websockets not installed. Run: pip install websockets")
    sys.exit(1)


class MultiReceiverClient:
    def __init__(self, server_url: str, output_dir: str = ".", verbose: bool = False):
        self.server_url = server_url
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.verbose = verbose
        self.running = True
        self.reconnect_delay = 2
        self.max_reconnect_delay = 30
        
        # Per-receiver state
        self.csv_files: Dict[str, dict] = {}  # receiver_id -> {writer, file}
        self.readings_count: Dict[str, int] = {}  # receiver_id -> count
        self.total_readings = 0
        
    def log(self, message: str, level: str = "INFO"):
        timestamp = datetime.now().strftime("%H:%M:%S")
        if level == "ERROR":
            print(f"[{timestamp}] ERROR: {message}")
        elif level == "WARN":
            print(f"[{timestamp}] WARN: {message}")
        elif self.verbose or level == "INFO":
            print(f"[{timestamp}] {message}")
    
    def get_csv_writer(self, receiver_id: str):
        """Get or create CSV writer for a receiver."""
        if receiver_id not in self.csv_files:
            csv_path = self.output_dir / f"rx_{receiver_id}.csv"
            csv_file = open(csv_path, "w", newline="", encoding="utf-8")
            csv_writer = csv.writer(csv_file)
            csv_writer.writerow(["timestamp_s", "rssi_dbm", "snr_db"])
            csv_file.flush()
            self.csv_files[receiver_id] = {"writer": csv_writer, "file": csv_file}
            self.readings_count[receiver_id] = 0
            self.log(f"Created CSV: {csv_path}")
        return self.csv_files[receiver_id]["writer"], self.csv_files[receiver_id]["file"]
    
    def write_csv(self, data: dict):
        """Write reading to appropriate CSV file."""
        receiver_id = data.get("receiver_id", "UNKNOWN")
        writer, file = self.get_csv_writer(receiver_id)
        writer.writerow([
            data.get("timestamp_s", ""),
            data.get("rssi", ""),
            data.get("snr", "")
        ])
        file.flush()
        self.readings_count[receiver_id] = self.readings_count.get(receiver_id, 0) + 1
        self.total_readings += 1
    
    def display_reading(self, data: dict):
        """Display a reading."""
        timestamp_s = data.get("timestamp_s", 0)
        receiver_id = data.get("receiver_id", "?")
        rssi = data.get("rssi", 0)
        snr = data.get("snr", 0)
        
        if rssi >= -50:
            signal = "████"
        elif rssi >= -60:
            signal = "███░"
        elif rssi >= -70:
            signal = "██░░"
        elif rssi >= -80:
            signal = "█░░░"
        else:
            signal = "░░░░"
        
        count = self.readings_count.get(receiver_id, 0)
        print(f"RX_{receiver_id}: {timestamp_s:8.3f}s | RSSI: {rssi:4} dBm | SNR: {snr:3} dB | {signal} | #{count}")
    
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
                    self.log("Connected! Waiting for data from all receivers...")
                    print("-" * 70)
                    current_delay = self.reconnect_delay
                    
                    async for message in websocket:
                        try:
                            data = json.loads(message)
                            
                            # Handle wrapped format
                            if isinstance(data, dict) and data.get("type") == "reading":
                                data = data.get("data", {})
                            elif isinstance(data, dict) and data.get("type") == "connected":
                                receivers = data.get("receivers", [])
                                self.log(f"Server has receivers: {', '.join(receivers)}")
                                continue
                            
                            if "receiver_id" in data or "rssi" in data:
                                self.display_reading(data)
                                self.write_csv(data)
                            elif self.verbose:
                                self.log(f"Received: {data}")
                                
                        except json.JSONDecodeError:
                            if self.verbose:
                                self.log(f"Non-JSON: {message[:100]}")
                                
            except websockets.exceptions.ConnectionClosed as e:
                self.log(f"Connection closed: {e}", "WARN")
            except ConnectionRefusedError:
                self.log("Connection refused - is the server running?", "ERROR")
            except Exception as e:
                self.log(f"Connection error: {e}", "ERROR")
            
            if self.running:
                self.log(f"Reconnecting in {current_delay} seconds...")
                await asyncio.sleep(current_delay)
                current_delay = min(current_delay * 2, self.max_reconnect_delay)
    
    def stop(self):
        """Stop and cleanup."""
        self.running = False
        for rid, data in self.csv_files.items():
            data["file"].close()
    
    def print_summary(self):
        """Print final summary."""
        print("\n" + "=" * 70)
        print("SUMMARY")
        print("=" * 70)
        for rid in sorted(self.readings_count.keys()):
            count = self.readings_count[rid]
            print(f"  Receiver {rid}: {count} readings")
        print(f"  TOTAL: {self.total_readings} readings")
        print(f"  Files saved to: {self.output_dir.absolute()}")
        print("=" * 70)
    
    async def run(self):
        """Main run loop."""
        try:
            await self.connect_and_listen()
        finally:
            self.stop()
            self.print_summary()


def main():
    parser = argparse.ArgumentParser(
        description="Multi-Receiver WebSocket Client",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python multi_client.py --server ws://172.20.10.2:8765/data
    python multi_client.py --server ws://MAC_IP:8765/data --output-dir ./my_data
        """
    )
    parser.add_argument(
        "--server", "-s",
        required=True,
        help="WebSocket server URL (e.g., ws://172.20.10.2:8765/data)"
    )
    parser.add_argument(
        "--output-dir", "-o",
        default=".",
        help="Directory to save CSV files (default: current directory)"
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show verbose output"
    )
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("  Multi-Receiver LoRa WebSocket Client")
    print("=" * 70)
    print(f"  Server: {args.server}")
    print(f"  Output: {args.output_dir}")
    print("  Press Ctrl+C to stop")
    print("=" * 70)
    print()
    
    client = MultiReceiverClient(
        server_url=args.server,
        output_dir=args.output_dir,
        verbose=args.verbose
    )
    
    try:
        asyncio.run(client.run())
    except KeyboardInterrupt:
        print("\nStopped by user.")


if __name__ == "__main__":
    main()
