"""
LoRa Receiver - WebSocket Approach
Runs on each Windows laptop
Streams data via WebSocket with automatic reconnection and local backup
"""

import serial
import serial.tools.list_ports
import json
import time
import re
import os
import csv
import asyncio
import websockets
from datetime import datetime, timezone
from collections import deque
import argparse
import logging
import threading

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class WebSocketReceiver:
    def __init__(self, receiver_id: str, ws_host: str, ws_port: int = 8765,
                 serial_port: str = None, baud_rate: int = 9600,
                 backup_folder: str = None):
        self.receiver_id = receiver_id
        self.ws_url = f"ws://{ws_host}:{ws_port}"
        self.serial_port = serial_port
        self.baud_rate = baud_rate
        self.serial_conn = None
        self.websocket = None
        self.connected = False
        
        # Receiver position
        self.position = {"x": 0.0, "y": 0.0, "z": 0.0}
        
        # Message queue for offline buffering
        self.message_queue = deque(maxlen=1000)
        
        # Local backup
        self.backup_folder = backup_folder
        self.backup_file = None
        if backup_folder:
            os.makedirs(backup_folder, exist_ok=True)
            self.backup_file = os.path.join(backup_folder, f"{receiver_id}_backup.csv")
            self._init_backup_file()
    
    def _init_backup_file(self):
        """Initialize backup CSV file"""
        if not os.path.exists(self.backup_file):
            with open(self.backup_file, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(['timestamp', 'timestamp_ms', 'receiver_id', 
                               'pos_x', 'pos_y', 'rssi', 'snr', 'sent'])
    
    def find_serial_port(self) -> str:
        """Auto-detect Wio-E5 serial port"""
        ports = serial.tools.list_ports.comports()
        for port in ports:
            if 'CH340' in port.description or 'USB' in port.description.upper():
                logger.info(f"Found Wio-E5 on {port.device}")
                return port.device
        return None
    
    def connect_serial(self):
        """Connect to Wio-E5"""
        port = self.serial_port or self.find_serial_port()
        if not port:
            raise Exception("No serial port found!")
        
        self.serial_conn = serial.Serial(port, self.baud_rate, timeout=0.1)
        logger.info(f"Connected to {port}")
        time.sleep(2)
    
    def parse_lora_packet(self, raw_data: str) -> dict:
        """Parse LoRa packet from Wio-E5"""
        pattern = r'\+RX[:\s]+"?([A-Fa-f0-9]+)"?,\s*(-?\d+),\s*(-?\d+)'
        match = re.search(pattern, raw_data)
        
        if match:
            hex_data = match.group(1)
            rssi = int(match.group(2))
            snr = int(match.group(3))
            
            try:
                payload = bytes.fromhex(hex_data).decode('utf-8', errors='ignore')
            except:
                payload = hex_data
            
            return {"payload": payload, "rssi": rssi, "snr": snr}
        
        rssi_match = re.search(r'RSSI[:\s]*(-?\d+)', raw_data, re.IGNORECASE)
        if rssi_match:
            return {"payload": raw_data, "rssi": int(rssi_match.group(1)), "snr": None}
        
        return None
    
    def backup_reading(self, data: dict, sent: bool = False):
        """Save reading to local backup file"""
        if not self.backup_file:
            return
        
        try:
            with open(self.backup_file, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([
                    data.get('timestamp'),
                    data.get('timestamp_ms'),
                    data.get('receiver_id'),
                    data.get('position', {}).get('x'),
                    data.get('position', {}).get('y'),
                    data.get('rssi'),
                    data.get('snr'),
                    'yes' if sent else 'no'
                ])
        except Exception as e:
            logger.error(f"Backup failed: {e}")
    
    async def connect_websocket(self):
        """Connect to WebSocket server with retry"""
        while True:
            try:
                self.websocket = await websockets.connect(
                    self.ws_url,
                    ping_interval=20,
                    ping_timeout=10
                )
                self.connected = True
                logger.info(f"Connected to WebSocket server at {self.ws_url}")
                
                # Send queued messages
                await self.flush_queue()
                
                # Keep connection alive
                while True:
                    try:
                        await self.websocket.recv()
                    except websockets.ConnectionClosed:
                        break
                        
            except Exception as e:
                self.connected = False
                logger.warning(f"WebSocket connection failed: {e}. Retrying in 3s...")
                await asyncio.sleep(3)
    
    async def flush_queue(self):
        """Send all queued messages"""
        while self.message_queue and self.connected:
            msg = self.message_queue.popleft()
            try:
                await self.websocket.send(msg)
            except:
                self.message_queue.appendleft(msg)
                break
    
    async def send_data(self, packet_data: dict):
        """Send data via WebSocket or queue if disconnected"""
        message = {
            "receiver_id": self.receiver_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "timestamp_ms": int(time.time() * 1000),
            "position": self.position,
            "rssi": packet_data.get("rssi"),
            "snr": packet_data.get("snr"),
            "payload": packet_data.get("payload")
        }
        
        json_msg = json.dumps(message)
        sent = False
        
        if self.connected and self.websocket:
            try:
                await self.websocket.send(json_msg)
                sent = True
                logger.info(f"Sent: RSSI={packet_data.get('rssi')} dBm")
            except:
                self.connected = False
                self.message_queue.append(json_msg)
                logger.warning("Send failed, queued message")
        else:
            self.message_queue.append(json_msg)
            logger.info(f"Queued (offline): RSSI={packet_data.get('rssi')} dBm")
        
        # Always backup locally
        self.backup_reading(message, sent)
    
    def read_serial_sync(self, data_queue: asyncio.Queue):
        """Synchronous serial reading in separate thread"""
        while True:
            try:
                if self.serial_conn and self.serial_conn.in_waiting > 0:
                    raw_line = self.serial_conn.readline().decode('utf-8', errors='ignore').strip()
                    if raw_line:
                        packet = self.parse_lora_packet(raw_line)
                        if packet and packet.get("rssi") is not None:
                            # Thread-safe queue
                            asyncio.run_coroutine_threadsafe(
                                data_queue.put(packet),
                                self.loop
                            )
                time.sleep(0.01)
            except Exception as e:
                logger.error(f"Serial error: {e}")
                time.sleep(1)
    
    async def process_data(self, data_queue: asyncio.Queue):
        """Process data from queue and send via WebSocket"""
        while True:
            packet = await data_queue.get()
            await self.send_data(packet)
    
    async def run_async(self):
        """Main async loop"""
        self.loop = asyncio.get_event_loop()
        data_queue = asyncio.Queue()
        
        # Start serial reader in separate thread
        serial_thread = threading.Thread(
            target=self.read_serial_sync,
            args=(data_queue,),
            daemon=True
        )
        serial_thread.start()
        
        # Run WebSocket connection and data processing concurrently
        await asyncio.gather(
            self.connect_websocket(),
            self.process_data(data_queue)
        )
    
    def run(self):
        """Start the receiver"""
        self.connect_serial()
        logger.info(f"Receiver {self.receiver_id} starting...")
        logger.info(f"WebSocket: {self.ws_url}")
        if self.backup_file:
            logger.info(f"Backup: {self.backup_file}")
        
        try:
            asyncio.run(self.run_async())
        except KeyboardInterrupt:
            logger.info("Shutting down...")
        finally:
            if self.serial_conn:
                self.serial_conn.close()


def main():
    parser = argparse.ArgumentParser(description='LoRa Receiver - WebSocket')
    parser.add_argument('--id', required=True, help='Receiver ID (R1, R2, R3)')
    parser.add_argument('--ws-host', required=True, help='WebSocket server IP')
    parser.add_argument('--ws-port', type=int, default=8765, help='WebSocket port')
    parser.add_argument('--serial-port', help='COM port (auto-detect if omitted)')
    parser.add_argument('--baud-rate', type=int, default=9600, help='Baud rate')
    parser.add_argument('--x', type=float, default=0.0, help='X position (meters)')
    parser.add_argument('--y', type=float, default=0.0, help='Y position (meters)')
    parser.add_argument('--backup', help='Local backup folder (optional)')
    
    args = parser.parse_args()
    
    receiver = WebSocketReceiver(
        receiver_id=args.id,
        ws_host=args.ws_host,
        ws_port=args.ws_port,
        serial_port=args.serial_port,
        baud_rate=args.baud_rate,
        backup_folder=args.backup
    )
    receiver.position = {"x": args.x, "y": args.y, "z": 0.0}
    receiver.run()


if __name__ == "__main__":
    main()
