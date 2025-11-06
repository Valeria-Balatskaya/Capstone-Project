#!/usr/bin/env python3
"""
RSSI-Based LoRaWAN Positioning System - MQTT Subscriber
macOS Compatible Version
"""

import json
import time
import logging
import os
from datetime import datetime
from typing import Dict, List, Tuple, Optional
import math

import paho.mqtt.client as mqtt
from influxdb_client import InfluxDBClient, Point
from influxdb_client.client.write_api import SYNCHRONOUS
import psycopg2
from psycopg2.extras import RealDictCursor
import numpy as np
from scipy.optimize import least_squares

# ============================================
# CONFIGURATION (macOS paths)
# ============================================

MQTT_BROKER = os.getenv("MQTT_BROKER", "localhost")
MQTT_PORT = int(os.getenv("MQTT_PORT", 1883))
MQTT_TOPIC = "application/+/device/+/event/up"

INFLUXDB_URL = os.getenv("INFLUXDB_URL", "http://localhost:8086")
INFLUXDB_TOKEN = os.getenv("INFLUXDB_TOKEN", "")
INFLUXDB_ORG = "lora_positioning"
INFLUXDB_BUCKET_POS = "positions"

POSTGRES_HOST = os.getenv("POSTGRES_HOST", "localhost")
POSTGRES_DB = os.getenv("POSTGRES_DB", "chirpstack")
POSTGRES_USER = os.getenv("POSTGRES_USER", "chirpstack")
POSTGRES_PASSWORD = os.getenv("POSTGRES_PASSWORD", "chirpstack")
POSTGRES_PORT = int(os.getenv("POSTGRES_PORT", 5432))

# Positioning parameters
PATH_LOSS_EXPONENT = 3.0
TX_POWER_DBM = -20
MIN_GATEWAYS = 3

# Logging configuration (macOS compatible)
log_dir = os.path.expanduser("~/lora_positioning/logs")
os.makedirs(log_dir, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(log_dir, 'lora_positioning.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# ============================================
# GATEWAY CACHE
# ============================================

class GatewayCache:
    """Load and cache gateway positions from PostgreSQL"""
    
    def __init__(self):
        self.cache = {}
        self.postgres_conn = None
        self.connect_postgres()
        self.load_gateways()
    
    def connect_postgres(self):
        """Connect to PostgreSQL"""
        try:
            self.postgres_conn = psycopg2.connect(
                host=POSTGRES_HOST,
                port=POSTGRES_PORT,
                database=POSTGRES_DB,
                user=POSTGRES_USER,
                password=POSTGRES_PASSWORD,
                connect_timeout=5
            )
            logger.info(f"Connected to PostgreSQL at {POSTGRES_HOST}:{POSTGRES_PORT}")
        except psycopg2.OperationalError as e:
            logger.error(f"PostgreSQL connection failed: {e}")
            logger.warning("Will retry in 10 seconds...")
            time.sleep(10)
            self.connect_postgres()
    
    def load_gateways(self):
        """Load gateway positions from database"""
        if not self.postgres_conn:
            return
        
        try:
            with self.postgres_conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT gateway_id, gateway_eui, latitude, longitude, altitude
                    FROM lora_positioning.gateways
                    WHERE active = TRUE
                """)
                rows = cur.fetchall()
                
                for row in rows:
                    self.cache[row['gateway_eui']] = {
                        'gateway_id': row['gateway_id'],
                        'lat': float(row['latitude']),
                        'lon': float(row['longitude']),
                        'alt': float(row['altitude']),
                        'x': float(row['latitude']) * 111000,
                        'y': float(row['longitude']) * 111000 * math.cos(math.radians(float(row['latitude']))),
                        'z': float(row['altitude'])
                    }
                
                logger.info(f"Loaded {len(self.cache)} gateways")
        
        except Exception as e:
            logger.error(f"Failed to load gateways: {e}")
    
    def get_gateway_position(self, gateway_eui: str) -> Optional[Dict]:
        """Get gateway position"""
        return self.cache.get(gateway_eui)

# ============================================
# HELPER FUNCTIONS
# ============================================

def rssi_to_distance(rssi_dbm: float, tx_power: float = TX_POWER_DBM, 
                     n: float = PATH_LOSS_EXPONENT) -> float:
    """Convert RSSI to distance"""
    if rssi_dbm > tx_power:
        rssi_dbm = tx_power
    distance = 10 ** ((tx_power - rssi_dbm) / (10 * n))
    return distance

def trilaterate(positions: List[Tuple[float, float, float]], 
                distances: List[float]) -> Optional[Tuple[float, float, float]]:
    """Solve trilateration using least squares"""
    
    if len(positions) < 3:
        return None
    
    def residuals(pos):
        x, y, z = pos
        residuals = []
        for (gx, gy, gz), d in zip(positions, distances):
            calc_d = math.sqrt((x-gx)**2 + (y-gy)**2 + (z-gz)**2)
            residuals.append(calc_d - d)
        return residuals
    
    x0 = np.mean([p[0] for p in positions])
    y0 = np.mean([p[1] for p in positions])
    z0 = np.mean([p[2] for p in positions])
    
    try:
        result = least_squares(residuals, [x0, y0, z0], max_nfev=1000)
        if result.success:
            return tuple(result.x)
    except:
        pass
    
    return None

# ============================================
# MQTT CALLBACKS
# ============================================

mqtt_client = None
influxdb_client = None
gateway_cache = None

def on_connect(client, userdata, flags, rc):
    """MQTT connection callback"""
    if rc == 0:
        logger.info("MQTT connected successfully")
        client.subscribe(MQTT_TOPIC)
    else:
        logger.error(f"MQTT connection failed with code {rc}")

def on_message(client, userdata, msg):
    """Process incoming MQTT message"""
    try:
        payload = json.loads(msg.payload.decode())
        
        device_name = payload.get('deviceName', 'Unknown')
        rx_info = payload.get('rxInfo', [])
        
        if len(rx_info) < MIN_GATEWAYS:
            logger.debug(f"Insufficient gateways ({len(rx_info)} < {MIN_GATEWAYS})")
            return
        
        measurements = []
        positions = []
        
        for rx in rx_info:
            gw_eui = rx.get('gatewayId', '')
            rssi = rx.get('rssi', -120)
            
            gw_pos = gateway_cache.get_gateway_position(gw_eui)
            if not gw_pos:
                logger.warning(f"Unknown gateway: {gw_eui}")
                continue
            
            distance = rssi_to_distance(rssi)
            
            measurements.append({
                'gateway_id': gw_eui,
                'rssi': rssi,
                'distance': distance
            })
            
            positions.append((gw_pos['x'], gw_pos['y'], gw_pos['z']))
        
        if len(measurements) < MIN_GATEWAYS:
            logger.warning("Not enough valid gateways for trilateration")
            return
        
        distances = [m['distance'] for m in measurements]
        position = trilaterate(positions, distances)
        
        if position:
            x, y, z = position
            logger.info(f"Device: {device_name} | Position: ({x:.2f}, {y:.2f}, {z:.2f})")
            
            try:
                point = Point("position") \
                    .tag("device", device_name) \
                    .field("x", float(x)) \
                    .field("y", float(y)) \
                    .field("z", float(z)) \
                    .field("num_gateways", len(measurements)) \
                    .time(datetime.utcnow())
                
                write_api = influxdb_client.write_api(write_options=SYNCHRONOUS)
                write_api.write(bucket=INFLUXDB_BUCKET_POS, record=point)
            
            except Exception as e:
                logger.error(f"InfluxDB write failed: {e}")
    
    except Exception as e:
        logger.error(f"Message processing error: {e}")

# ============================================
# MAIN
# ============================================

def main():
    """Main entry point"""
    global mqtt_client, influxdb_client, gateway_cache
    
    logger.info("Starting LoRa Positioning System (macOS)")
    
    gateway_cache = GatewayCache()
    
    try:
        influxdb_client = InfluxDBClient(url=INFLUXDB_URL, token=INFLUXDB_TOKEN, org=INFLUXDB_ORG)
        logger.info(f"Connected to InfluxDB at {INFLUXDB_URL}")
    except Exception as e:
        logger.error(f"InfluxDB connection failed: {e}")
        return
    
    mqtt_client = mqtt.Client(client_id="lora_positioning_subscriber", clean_session=True)
    mqtt_client.on_connect = on_connect
    mqtt_client.on_message = on_message
    
    while True:
        try:
            logger.info(f"Connecting to MQTT at {MQTT_BROKER}:{MQTT_PORT}")
            mqtt_client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
            break
        except Exception as e:
            logger.error(f"MQTT connection failed: {e}. Retrying in 10 seconds...")
            time.sleep(10)
    
    mqtt_client.loop_forever()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("Shutting down...")
        if mqtt_client:
            mqtt_client.disconnect()
        if influxdb_client:
            influxdb_client.close()
