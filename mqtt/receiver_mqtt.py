"""
LoRa Receiver Script - MQTT Approach
Runs on each Windows laptop
Reads serial data from Wio-E5 and publishes to MQTT broker
"""

import serial
import serial.tools.list_ports
import json
import time
import re
import paho.mqtt.client as mqtt
from datetime import datetime, timezone
import argparse
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class LoRaReceiver:
    def __init__(self, receiver_id: str, mqtt_host: str, mqtt_port: int = 1883,
                 serial_port: str = None, baud_rate: int = 9600):
        self.receiver_id = receiver_id
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.serial_port = serial_port
        self.baud_rate = baud_rate
        self.mqtt_client = None
        self.serial_conn = None
        
        # Receiver's known position (set via command line)
        self.position = {"x": 0.0, "y": 0.0, "z": 0.0}
        
    def find_serial_port(self) -> str:
        """Auto-detect Wio-E5 serial port"""
        ports = serial.tools.list_ports.comports()
        for port in ports:
            if 'CH340' in port.description or 'USB' in port.description.upper():
                logger.info(f"Found potential Wio-E5 on {port.device}: {port.description}")
                return port.device
        
        if ports:
            logger.warning("Could not auto-detect Wio-E5. Available ports:")
            for port in ports:
                logger.warning(f"  {port.device}: {port.description}")
        return None
    
    def connect_mqtt(self):
        """Connect to MQTT broker"""
        self.mqtt_client = mqtt.Client(client_id=f"receiver_{self.receiver_id}")
        self.mqtt_client.on_connect = self._on_mqtt_connect
        self.mqtt_client.on_disconnect = self._on_mqtt_disconnect
        
        try:
            self.mqtt_client.connect(self.mqtt_host, self.mqtt_port, keepalive=60)
            self.mqtt_client.loop_start()
            logger.info(f"Connected to MQTT broker at {self.mqtt_host}:{self.mqtt_port}")
        except Exception as e:
            logger.error(f"Failed to connect to MQTT broker: {e}")
            raise
    
    def _on_mqtt_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logger.info("MQTT connection established")
        else:
            logger.error(f"MQTT connection failed with code {rc}")
    
    def _on_mqtt_disconnect(self, client, userdata, rc):
        logger.warning(f"MQTT disconnected with code {rc}")
    
    def connect_serial(self):
        """Connect to Wio-E5 via serial"""
        port = self.serial_port or self.find_serial_port()
        if not port:
            raise Exception("No serial port found. Please specify with --serial-port")
        
        try:
            self.serial_conn = serial.Serial(port, self.baud_rate, timeout=1)
            logger.info(f"Connected to serial port {port} at {self.baud_rate} baud")
            time.sleep(2)
        except Exception as e:
            logger.error(f"Failed to connect to serial port: {e}")
            raise
    
    def parse_lora_packet(self, raw_data: str) -> dict:
        """
        Parse LoRa packet from Wio-E5
        Expected format: +RX "HEXDATA",-45,12 (hex_data, RSSI, SNR)
        """
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
            
            return {
                "payload": payload,
                "hex_data": hex_data,
                "rssi": rssi,
                "snr": snr
            }
        
        # Fallback: just look for RSSI
        rssi_pattern = r'RSSI[:\s]*(-?\d+)'
        rssi_match = re.search(rssi_pattern, raw_data, re.IGNORECASE)
        if rssi_match:
            return {
                "payload": raw_data,
                "rssi": int(rssi_match.group(1)),
                "snr": None
            }
        
        return None
    
    def publish_data(self, packet_data: dict):
        """Publish received packet to MQTT"""
        message = {
            "receiver_id": self.receiver_id,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "timestamp_ms": int(time.time() * 1000),
            "position": self.position,
            "rssi": packet_data.get("rssi"),
            "snr": packet_data.get("snr"),
            "payload": packet_data.get("payload"),
            "raw_hex": packet_data.get("hex_data")
        }
        
        topic = "lora/receivers"
        self.mqtt_client.publish(topic, json.dumps(message), qos=1)
        logger.info(f"Published: RSSI={packet_data.get('rssi')} dBm")
    
    def run(self):
        """Main loop - read serial and publish to MQTT"""
        self.connect_mqtt()
        self.connect_serial()
        
        logger.info(f"Receiver {self.receiver_id} running. Press Ctrl+C to stop.")
        
        try:
            while True:
                if self.serial_conn.in_waiting > 0:
                    raw_line = self.serial_conn.readline().decode('utf-8', errors='ignore').strip()
                    
                    if raw_line:
                        logger.debug(f"Raw: {raw_line}")
                        packet = self.parse_lora_packet(raw_line)
                        
                        if packet and packet.get("rssi") is not None:
                            self.publish_data(packet)
                        else:
                            logger.debug(f"Unparsed line: {raw_line}")
                
                time.sleep(0.01)
                
        except KeyboardInterrupt:
            logger.info("Shutting down...")
        finally:
            if self.serial_conn:
                self.serial_conn.close()
            if self.mqtt_client:
                self.mqtt_client.loop_stop()
                self.mqtt_client.disconnect()


def main():
    parser = argparse.ArgumentParser(description='LoRa Receiver - MQTT Publisher')
    parser.add_argument('--id', required=True, help='Unique receiver ID (e.g., R1, R2, R3)')
    parser.add_argument('--mqtt-host', required=True, help='MQTT broker IP address')
    parser.add_argument('--mqtt-port', type=int, default=1883, help='MQTT broker port')
    parser.add_argument('--serial-port', help='Serial port (e.g., COM3). Auto-detect if not specified')
    parser.add_argument('--baud-rate', type=int, default=9600, help='Serial baud rate')
    parser.add_argument('--x', type=float, default=0.0, help='Receiver X position (meters)')
    parser.add_argument('--y', type=float, default=0.0, help='Receiver Y position (meters)')
    parser.add_argument('--z', type=float, default=0.0, help='Receiver Z position (meters)')
    
    args = parser.parse_args()
    
    receiver = LoRaReceiver(
        receiver_id=args.id,
        mqtt_host=args.mqtt_host,
        mqtt_port=args.mqtt_port,
        serial_port=args.serial_port,
        baud_rate=args.baud_rate
    )
    receiver.position = {"x": args.x, "y": args.y, "z": args.z}
    
    receiver.run()


if __name__ == "__main__":
    main()
