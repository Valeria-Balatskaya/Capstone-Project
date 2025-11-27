"""
Simple Central Processor - Reads from Shared Folder (CSV)
Runs on Mac - watches CSV files and performs trilateration
No MQTT needed
"""

import csv
import time
import math
import os
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from collections import defaultdict
import argparse
import logging

try:
    from scipy.optimize import minimize
    import numpy as np
    SCIPY_AVAILABLE = True
except ImportError:
    SCIPY_AVAILABLE = False
    print("Warning: scipy not installed. Install with: pip3 install scipy numpy")

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RSSIToDistance:
    """Convert RSSI to distance"""
    
    def __init__(self, rssi_at_1m: float = -40, path_loss_exponent: float = 2.5):
        self.rssi_at_1m = rssi_at_1m
        self.path_loss_exponent = path_loss_exponent
    
    def calculate(self, rssi: float) -> float:
        if rssi >= self.rssi_at_1m:
            return 1.0
        distance = 10 ** ((self.rssi_at_1m - rssi) / (10 * self.path_loss_exponent))
        return distance


class SimpleTrilaterator:
    """2D Trilateration"""
    
    def __init__(self, rssi_converter: RSSIToDistance):
        self.rssi_converter = rssi_converter
    
    def trilaterate(self, receivers: List[Dict], rssi_values: List[float]) -> Tuple[float, float]:
        """Find tag position from 3+ receiver readings"""
        if len(receivers) < 3:
            raise ValueError("Need at least 3 receivers")
        
        if not SCIPY_AVAILABLE:
            # Fallback: simple weighted centroid
            return self._simple_centroid(receivers, rssi_values)
        
        distances = [self.rssi_converter.calculate(rssi) for rssi in rssi_values]
        
        # Initial guess: centroid
        init_x = sum(r["x"] for r in receivers) / len(receivers)
        init_y = sum(r["y"] for r in receivers) / len(receivers)
        
        def objective(point):
            x, y = point
            error = 0
            for i, receiver in enumerate(receivers):
                est_dist = math.sqrt((x - receiver["x"])**2 + (y - receiver["y"])**2)
                error += (est_dist - distances[i])**2
            return error
        
        result = minimize(objective, [init_x, init_y], method='L-BFGS-B')
        return result.x[0], result.x[1]
    
    def _simple_centroid(self, receivers: List[Dict], rssi_values: List[float]) -> Tuple[float, float]:
        """Fallback method: weighted average based on signal strength"""
        # Higher RSSI = closer = higher weight
        weights = [10 ** (rssi / 10) for rssi in rssi_values]  # Convert dBm to linear
        total_weight = sum(weights)
        
        x = sum(r["x"] * w for r, w in zip(receivers, weights)) / total_weight
        y = sum(r["y"] * w for r, w in zip(receivers, weights)) / total_weight
        return x, y


class SimpleProcessor:
    """Watches CSV files and computes position"""
    
    def __init__(self, data_folder: str, time_window_sec: float = 2.0,
                 rssi_at_1m: float = -40, path_loss: float = 2.5):
        self.data_folder = data_folder
        self.time_window_sec = time_window_sec
        
        self.rssi_converter = RSSIToDistance(rssi_at_1m, path_loss)
        self.trilaterator = SimpleTrilaterator(self.rssi_converter)
        
        # Track file positions (to read only new lines)
        self.file_positions: Dict[str, int] = {}
        
        # Position smoothing
        self.position_history: List[Tuple[float, float]] = []
        self.max_history = 5
    
    def get_csv_files(self) -> List[str]:
        """Find all receiver CSV files"""
        files = []
        if os.path.exists(self.data_folder):
            for f in os.listdir(self.data_folder):
                if f.endswith('_readings.csv'):
                    files.append(os.path.join(self.data_folder, f))
        return files
    
    def read_new_lines(self, filepath: str) -> List[dict]:
        """Read only new lines from CSV file"""
        if not os.path.exists(filepath):
            return []
        
        # Get last read position
        last_pos = self.file_positions.get(filepath, 0)
        
        readings = []
        try:
            with open(filepath, 'r', newline='') as f:
                # Skip to last position
                f.seek(last_pos)
                
                # If at beginning, skip header
                if last_pos == 0:
                    f.readline()
                
                reader = csv.DictReader(
                    f,
                    fieldnames=['timestamp', 'timestamp_ms', 'receiver_id',
                               'pos_x', 'pos_y', 'rssi', 'snr', 'payload']
                )
                
                for row in reader:
                    try:
                        readings.append({
                            'timestamp': row['timestamp'],
                            'timestamp_ms': int(row['timestamp_ms']),
                            'receiver_id': row['receiver_id'],
                            'position': {'x': float(row['pos_x']), 'y': float(row['pos_y'])},
                            'rssi': int(row['rssi']) if row['rssi'] else None
                        })
                    except (ValueError, KeyError):
                        continue
                
                # Save new position
                self.file_positions[filepath] = f.tell()
                
        except Exception as e:
            logger.error(f"Error reading {filepath}: {e}")
        
        return readings
    
    def collect_recent_readings(self) -> Dict[str, dict]:
        """Collect most recent reading from each receiver"""
        all_readings: Dict[str, dict] = {}
        now_ms = int(time.time() * 1000)
        window_ms = int(self.time_window_sec * 1000)
        
        for csv_file in self.get_csv_files():
            new_readings = self.read_new_lines(csv_file)
            
            for reading in new_readings:
                # Check if within time window
                age_ms = now_ms - reading['timestamp_ms']
                if age_ms <= window_ms and reading.get('rssi') is not None:
                    receiver_id = reading['receiver_id']
                    # Keep most recent reading per receiver
                    if receiver_id not in all_readings or \
                       reading['timestamp_ms'] > all_readings[receiver_id]['timestamp_ms']:
                        all_readings[receiver_id] = reading
        
        return all_readings
    
    def compute_position(self, readings: Dict[str, dict]) -> Optional[Tuple[float, float]]:
        """Compute tag position from readings"""
        if len(readings) < 3:
            return None
        
        receivers = []
        rssi_values = []
        
        for receiver_id, data in readings.items():
            receivers.append(data['position'])
            rssi_values.append(data['rssi'])
        
        try:
            x, y = self.trilaterator.trilaterate(receivers, rssi_values)
            
            # Smooth
            self.position_history.append((x, y))
            if len(self.position_history) > self.max_history:
                self.position_history.pop(0)
            
            avg_x = sum(p[0] for p in self.position_history) / len(self.position_history)
            avg_y = sum(p[1] for p in self.position_history) / len(self.position_history)
            
            return avg_x, avg_y
            
        except Exception as e:
            logger.error(f"Trilateration failed: {e}")
            return None
    
    def run(self, poll_interval: float = 0.5):
        """Main loop - poll CSV files and compute position"""
        logger.info(f"Watching folder: {self.data_folder}")
        logger.info(f"Time window: {self.time_window_sec}s, Poll interval: {poll_interval}s")
        logger.info("Waiting for data from receivers...")
        
        try:
            while True:
                readings = self.collect_recent_readings()
                
                if len(readings) >= 3:
                    position = self.compute_position(readings)
                    
                    if position:
                        # Display results
                        print("\n" + "="*50)
                        print(f"📍 TAG POSITION: X={position[0]:.2f}m, Y={position[1]:.2f}m")
                        print("-"*50)
                        
                        for rid, data in readings.items():
                            dist = self.rssi_converter.calculate(data['rssi'])
                            print(f"  {rid}: RSSI={data['rssi']}dBm → {dist:.2f}m")
                        
                        print("="*50)
                
                elif len(readings) > 0:
                    logger.debug(f"Have {len(readings)} receivers, need 3")
                
                time.sleep(poll_interval)
                
        except KeyboardInterrupt:
            logger.info("Shutting down...")


def main():
    parser = argparse.ArgumentParser(description='Simple Position Processor (CSV)')
    parser.add_argument('--folder', required=True, help='Shared folder with CSV files')
    parser.add_argument('--time-window', type=float, default=2.0, help='Time window (seconds)')
    parser.add_argument('--poll-interval', type=float, default=0.5, help='Poll interval (seconds)')
    parser.add_argument('--rssi-1m', type=float, default=-40, help='RSSI at 1 meter')
    parser.add_argument('--path-loss', type=float, default=2.5, help='Path loss exponent')
    
    args = parser.parse_args()
    
    processor = SimpleProcessor(
        data_folder=args.folder,
        time_window_sec=args.time_window,
        rssi_at_1m=args.rssi_1m,
        path_loss=args.path_loss
    )
    processor.run(poll_interval=args.poll_interval)


if __name__ == "__main__":
    main()
