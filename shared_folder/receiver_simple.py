"""
Simple LoRa Receiver - Writes to Shared Folder (CSV)
Runs on each Windows laptop
No MQTT needed - just writes to a network share
"""

import serial
import serial.tools.list_ports
import csv
import time
import re
import os
from datetime import datetime
import argparse
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SimpleReceiver:
    def __init__(self, receiver_id: str, output_folder: str,
                 position_x: float, position_y: float,
                 serial_port: str = None, baud_rate: int = 9600):
        self.receiver_id = receiver_id
        self.output_folder = output_folder
        self.position = {"x": position_x, "y": position_y}
        self.serial_port = serial_port
        self.baud_rate = baud_rate
        self.serial_conn = None
        
        # CSV file path
        self.csv_file = os.path.join(output_folder, f"{receiver_id}_readings.csv")
        
    def find_serial_port(self) -> str:
        """Auto-detect Wio-E5 serial port"""
        ports = serial.tools.list_ports.comports()
        for port in ports:
            if 'CH340' in port.description or 'USB' in port.description.upper():
                logger.info(f"Found Wio-E5 on {port.device}")
                return port.device
        
        if ports:
            logger.warning("Available ports:")
            for port in ports:
                logger.warning(f"  {port.device}: {port.description}")
        return None
    
    def connect_serial(self):
        """Connect to Wio-E5"""
        port = self.serial_port or self.find_serial_port()
        if not port:
            raise Exception("No serial port found!")
        
        self.serial_conn = serial.Serial(port, self.baud_rate, timeout=1)
        logger.info(f"Connected to {port}")
        time.sleep(2)
    
    def init_csv(self):
        """Create CSV file with headers if it doesn't exist"""
        os.makedirs(self.output_folder, exist_ok=True)
        
        if not os.path.exists(self.csv_file):
            with open(self.csv_file, 'w', newline='') as f:
                writer = csv.writer(f)
                writer.writerow([
                    'timestamp', 'timestamp_ms', 'receiver_id',
                    'pos_x', 'pos_y', 'rssi', 'snr', 'payload'
                ])
            logger.info(f"Created {self.csv_file}")
    
    def parse_lora_packet(self, raw_data: str) -> dict:
        """Parse LoRa packet - adjust regex for your Wio-E5 output format"""
        # Pattern: +RX "HEXDATA",-45,12
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
        
        # Fallback: just look for RSSI
        rssi_match = re.search(r'RSSI[:\s]*(-?\d+)', raw_data, re.IGNORECASE)
        if rssi_match:
            return {"payload": raw_data, "rssi": int(rssi_match.group(1)), "snr": None}
        
        return None
    
    def write_reading(self, packet: dict):
        """Append reading to CSV file"""
        now = datetime.now()
        
        row = [
            now.isoformat(),
            int(time.time() * 1000),
            self.receiver_id,
            self.position["x"],
            self.position["y"],
            packet.get("rssi"),
            packet.get("snr"),
            packet.get("payload", "")
        ]
        
        try:
            with open(self.csv_file, 'a', newline='') as f:
                writer = csv.writer(f)
                writer.writerow(row)
            logger.info(f"Logged: RSSI={packet.get('rssi')} dBm")
        except Exception as e:
            logger.error(f"Failed to write CSV: {e}")
    
    def run(self):
        """Main loop"""
        self.init_csv()
        self.connect_serial()
        
        logger.info(f"Receiver {self.receiver_id} running. Writing to {self.csv_file}")
        logger.info("Press Ctrl+C to stop.")
        
        try:
            while True:
                if self.serial_conn.in_waiting > 0:
                    raw_line = self.serial_conn.readline().decode('utf-8', errors='ignore').strip()
                    
                    if raw_line:
                        packet = self.parse_lora_packet(raw_line)
                        if packet and packet.get("rssi") is not None:
                            self.write_reading(packet)
                
                time.sleep(0.01)
                
        except KeyboardInterrupt:
            logger.info("Shutting down...")
        finally:
            if self.serial_conn:
                self.serial_conn.close()


def main():
    parser = argparse.ArgumentParser(description='Simple LoRa Receiver (CSV output)')
    parser.add_argument('--id', required=True, help='Receiver ID (R1, R2, R3)')
    parser.add_argument('--output', required=True, help='Shared folder path (e.g., \\\\MAC\\lora_data)')
    parser.add_argument('--x', type=float, required=True, help='Receiver X position (meters)')
    parser.add_argument('--y', type=float, required=True, help='Receiver Y position (meters)')
    parser.add_argument('--serial-port', help='COM port (auto-detect if omitted)')
    parser.add_argument('--baud-rate', type=int, default=9600, help='Baud rate')
    
    args = parser.parse_args()
    
    receiver = SimpleReceiver(
        receiver_id=args.id,
        output_folder=args.output,
        position_x=args.x,
        position_y=args.y,
        serial_port=args.serial_port,
        baud_rate=args.baud_rate
    )
    receiver.run()


if __name__ == "__main__":
    main()
