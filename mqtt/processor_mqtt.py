"""
Central Processor - MQTT Approach
Runs on Mac (or any OS)
Subscribes to MQTT, collects RSSI from all receivers, performs trilateration
"""

import json
import time
import math
from collections import defaultdict
from datetime import datetime, timezone
from typing import Dict, List, Tuple, Optional
import paho.mqtt.client as mqtt
import argparse
import logging
import threading

try:
    import numpy as np
    from scipy.optimize import minimize
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False
    print("Warning: scipy not installed. Using fallback method.")
    print("Install with: pip3 install scipy numpy")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RSSIToDistance:
    """Convert RSSI to distance using Log-Distance Path Loss Model"""
    
    def __init__(self, rssi_at_1m: float = -40, path_loss_exponent: float = 2.5):
        self.rssi_at_1m = rssi_at_1m
        self.path_loss_exponent = path_loss_exponent
    
    def calculate(self, rssi: float) -> float:
        """Convert RSSI (dBm) to distance (meters)"""
        if rssi >= self.rssi_at_1m:
            return 1.0
        
        distance = 10 ** ((self.rssi_at_1m - rssi) / (10 * self.path_loss_exponent))
        return distance


class Trilaterator:
    """Perform 2D/3D trilateration to find tag position"""
    
    def __init__(self, rssi_converter: RSSIToDistance):
        self.rssi_converter = rssi_converter
    
    def trilaterate_2d(self, receivers: List[Dict], rssi_values: List[float]) -> Tuple[float, float]:
        """2D trilateration using least squares optimization"""
        if len(receivers) < 3:
            raise ValueError("Need at least 3 receivers for trilateration")
        
        distances = [self.rssi_converter.calculate(rssi) for rssi in rssi_values]
        
        if not SCIPY_AVAILABLE:
            return self._weighted_centroid(receivers, rssi_values)
        
        initial_x = sum(r["x"] for r in receivers) / len(receivers)
        initial_y = sum(r["y"] for r in receivers) / len(receivers)
        
        def objective(point):
            x, y = point
            error = 0
            for i, receiver in enumerate(receivers):
                estimated_dist = math.sqrt((x - receiver["x"])**2 + (y - receiver["y"])**2)
                error += (estimated_dist - distances[i])**2
            return error
        
        result = minimize(objective, [initial_x, initial_y], method='L-BFGS-B')
        return result.x[0], result.x[1]
    
    def trilaterate_3d(self, receivers: List[Dict], rssi_values: List[float]) -> Tuple[float, float, float]:
        """3D trilateration using least squares optimization"""
        if len(receivers) < 4:
            logger.warning("3D trilateration works best with 4+ receivers")
        
        distances = [self.rssi_converter.calculate(rssi) for rssi in rssi_values]
        
        initial_x = sum(r["x"] for r in receivers) / len(receivers)
        initial_y = sum(r["y"] for r in receivers) / len(receivers)
        initial_z = sum(r.get("z", 0) for r in receivers) / len(receivers)
        
        def objective(point):
            x, y, z = point
            error = 0
            for i, receiver in enumerate(receivers):
                rx, ry, rz = receiver["x"], receiver["y"], receiver.get("z", 0)
                estimated_dist = math.sqrt((x - rx)**2 + (y - ry)**2 + (z - rz)**2)
                error += (estimated_dist - distances[i])**2
            return error
        
        result = minimize(objective, [initial_x, initial_y, initial_z], method='L-BFGS-B')
        return result.x[0], result.x[1], result.x[2]
    
    def _weighted_centroid(self, receivers: List[Dict], rssi_values: List[float]) -> Tuple[float, float]:
        """Fallback: weighted average based on signal strength"""
        weights = [10 ** (rssi / 10) for rssi in rssi_values]
        total_weight = sum(weights)
        
        x = sum(r["x"] * w for r, w in zip(receivers, weights)) / total_weight
        y = sum(r["y"] * w for r, w in zip(receivers, weights)) / total_weight
        return x, y


class CentralProcessor:
    """Main processor that collects data and computes position"""
    
    def __init__(self, mqtt_host: str, mqtt_port: int = 1883,
                 time_window_ms: int = 500, min_receivers: int = 3,
                 use_3d: bool = False):
        self.mqtt_host = mqtt_host
        self.mqtt_port = mqtt_port
        self.time_window_ms = time_window_ms
        self.min_receivers = min_receivers
        self.use_3d = use_3d
        
        self.mqtt_client = None
        self.rssi_converter = RSSIToDistance()
        self.trilaterator = Trilaterator(self.rssi_converter)
        
        # Buffer to collect readings from multiple receivers
        self.reading_buffer: Dict[int, Dict[str, dict]] = defaultdict(dict)
        self.buffer_lock = threading.Lock()
        
        # Position smoothing
        self.position_history: List[Tuple[float, float]] = []
        self.max_history = 5
        
        # Callback for external integrations
        self.on_position_update = None
    
    def connect(self):
        """Connect to MQTT broker"""
        self.mqtt_client = mqtt.Client(client_id="central_processor")
        self.mqtt_client.on_connect = self._on_connect
        self.mqtt_client.on_message = self._on_message
        
        try:
            self.mqtt_client.connect(self.mqtt_host, self.mqtt_port, keepalive=60)
            logger.info(f"Connected to MQTT broker at {self.mqtt_host}:{self.mqtt_port}")
        except Exception as e:
            logger.error(f"Failed to connect to MQTT broker: {e}")
            raise
    
    def _on_connect(self, client, userdata, flags, rc):
        if rc == 0:
            logger.info("MQTT connected, subscribing to lora/receivers")
            client.subscribe("lora/receivers", qos=1)
        else:
            logger.error(f"MQTT connection failed with code {rc}")
    
    def _on_message(self, client, userdata, msg):
        """Handle incoming MQTT messages"""
        try:
            data = json.loads(msg.payload.decode('utf-8'))
            self._process_reading(data)
        except Exception as e:
            logger.error(f"Error processing message: {e}")
    
    def _process_reading(self, data: dict):
        """Process a single receiver reading"""
        timestamp_ms = data.get("timestamp_ms", int(time.time() * 1000))
        receiver_id = data.get("receiver_id")
        
        if not receiver_id:
            return
        
        # Create time bucket
        bucket = timestamp_ms // self.time_window_ms
        
        with self.buffer_lock:
            self.reading_buffer[bucket][receiver_id] = {
                "position": data.get("position", {"x": 0, "y": 0, "z": 0}),
                "rssi": data.get("rssi"),
                "snr": data.get("snr"),
                "timestamp_ms": timestamp_ms
            }
            
            logger.debug(f"Received from {receiver_id}: RSSI={data.get('rssi')}")
            
            if len(self.reading_buffer[bucket]) >= self.min_receivers:
                self._compute_position(bucket)
            
            self._cleanup_old_buckets(bucket)
    
    def _compute_position(self, bucket: int):
        """Compute position from readings in a time bucket"""
        readings = self.reading_buffer[bucket]
        
        receivers = []
        rssi_values = []
        receiver_ids = []
        
        for receiver_id, data in readings.items():
            if data.get("rssi") is not None:
                receivers.append(data["position"])
                rssi_values.append(data["rssi"])
                receiver_ids.append(receiver_id)
        
        if len(receivers) < self.min_receivers:
            return
        
        try:
            if self.use_3d:
                x, y, z = self.trilaterator.trilaterate_3d(receivers, rssi_values)
                position = {"x": round(x, 2), "y": round(y, 2), "z": round(z, 2)}
            else:
                x, y = self.trilaterator.trilaterate_2d(receivers, rssi_values)
                position = {"x": round(x, 2), "y": round(y, 2)}
            
            # Smooth
            smoothed = self._smooth_position(x, y)
            
            # Display
            print("\n" + "="*50)
            print(f"📍 TAG POSITION: X={smoothed[0]:.2f}m, Y={smoothed[1]:.2f}m")
            print("-"*50)
            for i, rid in enumerate(receiver_ids):
                dist = self.rssi_converter.calculate(rssi_values[i])
                print(f"  {rid}: RSSI={rssi_values[i]}dBm → {dist:.2f}m")
            print("="*50)
            
            if self.on_position_update:
                self.on_position_update({
                    "position": {"x": smoothed[0], "y": smoothed[1]},
                    "raw_position": position,
                    "timestamp": datetime.now(timezone.utc).isoformat()
                })
            
            del self.reading_buffer[bucket]
            
        except Exception as e:
            logger.error(f"Trilateration failed: {e}")
    
    def _smooth_position(self, x: float, y: float) -> Tuple[float, float]:
        """Apply moving average smoothing"""
        self.position_history.append((x, y))
        if len(self.position_history) > self.max_history:
            self.position_history.pop(0)
        
        avg_x = sum(p[0] for p in self.position_history) / len(self.position_history)
        avg_y = sum(p[1] for p in self.position_history) / len(self.position_history)
        
        return avg_x, avg_y
    
    def _cleanup_old_buckets(self, current_bucket: int):
        """Remove old time buckets"""
        old_buckets = [b for b in self.reading_buffer.keys() if b < current_bucket - 10]
        for bucket in old_buckets:
            del self.reading_buffer[bucket]
    
    def calibrate(self, rssi_at_1m: float, path_loss_exponent: float):
        """Update calibration parameters"""
        self.rssi_converter.rssi_at_1m = rssi_at_1m
        self.rssi_converter.path_loss_exponent = path_loss_exponent
        logger.info(f"Calibration: RSSI@1m={rssi_at_1m}, path_loss={path_loss_exponent}")
    
    def run(self):
        """Start the processor"""
        self.connect()
        logger.info("Central processor running. Waiting for receiver data...")
        logger.info(f"Expecting {self.min_receivers} receivers, time window: {self.time_window_ms}ms")
        
        try:
            self.mqtt_client.loop_forever()
        except KeyboardInterrupt:
            logger.info("Shutting down...")
        finally:
            self.mqtt_client.disconnect()


def main():
    parser = argparse.ArgumentParser(description='Central Processor - MQTT Trilateration')
    parser.add_argument('--mqtt-host', default='localhost', help='MQTT broker IP')
    parser.add_argument('--mqtt-port', type=int, default=1883, help='MQTT port')
    parser.add_argument('--time-window', type=int, default=500, help='Time window (ms)')
    parser.add_argument('--min-receivers', type=int, default=3, help='Minimum receivers')
    parser.add_argument('--rssi-1m', type=float, default=-40, help='RSSI at 1 meter')
    parser.add_argument('--path-loss', type=float, default=2.5, help='Path loss exponent')
    parser.add_argument('--3d', dest='use_3d', action='store_true', help='Use 3D trilateration')
    
    args = parser.parse_args()
    
    processor = CentralProcessor(
        mqtt_host=args.mqtt_host,
        mqtt_port=args.mqtt_port,
        time_window_ms=args.time_window,
        min_receivers=args.min_receivers,
        use_3d=args.use_3d
    )
    processor.calibrate(args.rssi_1m, args.path_loss)
    processor.run()


if __name__ == "__main__":
    main()
