#!/usr/bin/env python3
"""
Trilateration Calculator for LoRa Indoor Positioning
=====================================================
Takes RSSI readings from 3 receivers and estimates tag position.

Usage:
    1. First, run calibration to get RSSI at 1 meter
    2. Then run trilateration with live data

Calibration:
    python trilateration.py --calibrate --receiver A --distance 1.0

Live positioning:
    python trilateration.py --input all_receivers.csv
"""

import argparse
import csv
import math
import time
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple
from collections import deque


@dataclass
class ReceiverPosition:
    """Known position of a receiver in meters."""
    x: float
    y: float
    name: str


# ============================================================
# CONFIGURATION - EDIT THESE VALUES FOR YOUR SETUP!
# ============================================================

# Receiver positions in meters (measure these!)
RECEIVERS = {
    "A": ReceiverPosition(x=0.0, y=0.0, name="A"),   # Mac - set as origin
    "B": ReceiverPosition(x=0.0, y=6.0, name="B"),   # Windows #1
    "C": ReceiverPosition(x=8.0, y=6.0, name="C"),   # Windows #2
}

# RSSI calibration values (calibrate these!)
RSSI_AT_1M = -45      # RSSI value measured at exactly 1 meter distance
PATH_LOSS_N = 2.5     # Path loss exponent: 2.0=open, 2.5=indoor, 3.5=walls

# ============================================================


def rssi_to_distance(rssi: float, rssi_1m: float = RSSI_AT_1M, n: float = PATH_LOSS_N) -> float:
    """
    Convert RSSI to distance using log-distance path loss model.
    
    Formula: distance = 10 ^ ((RSSI_1m - RSSI) / (10 * n))
    
    Args:
        rssi: Received signal strength in dBm
        rssi_1m: RSSI at 1 meter (calibration value)
        n: Path loss exponent
    
    Returns:
        Estimated distance in meters
    """
    if rssi >= rssi_1m:
        return 0.1  # Very close, minimum distance
    
    distance = 10 ** ((rssi_1m - rssi) / (10 * n))
    return round(distance, 2)


def trilaterate(distances: Dict[str, float]) -> Optional[Tuple[float, float]]:
    """
    Calculate position using trilateration from 3 receivers.
    
    Uses least squares approximation for overdetermined system.
    
    Args:
        distances: Dict of receiver_id -> distance in meters
    
    Returns:
        (x, y) position in meters, or None if insufficient data
    """
    # Need at least 3 receivers
    if len(distances) < 3:
        return None
    
    # Get receiver positions and distances
    receivers = []
    for rid, dist in distances.items():
        if rid in RECEIVERS:
            receivers.append((RECEIVERS[rid], dist))
    
    if len(receivers) < 3:
        return None
    
    # Use first receiver as reference (A)
    r1, d1 = receivers[0]
    r2, d2 = receivers[1]
    r3, d3 = receivers[2]
    
    # Trilateration equations:
    # (x - x1)² + (y - y1)² = d1²
    # (x - x2)² + (y - y2)² = d2²
    # (x - x3)² + (y - y3)² = d3²
    
    # Linearize by subtracting first equation from others:
    # 2(x2-x1)x + 2(y2-y1)y = d1² - d2² + x2² - x1² + y2² - y1²
    # 2(x3-x1)x + 2(y3-y1)y = d1² - d3² + x3² - x1² + y3² - y1²
    
    A = 2 * (r2.x - r1.x)
    B = 2 * (r2.y - r1.y)
    C = d1**2 - d2**2 + r2.x**2 - r1.x**2 + r2.y**2 - r1.y**2
    
    D = 2 * (r3.x - r1.x)
    E = 2 * (r3.y - r1.y)
    F = d1**2 - d3**2 + r3.x**2 - r1.x**2 + r3.y**2 - r1.y**2
    
    # Solve system: Ax + By = C, Dx + Ey = F
    denom = A * E - B * D
    
    if abs(denom) < 0.0001:
        # Receivers are collinear, can't solve
        return None
    
    x = (C * E - B * F) / denom
    y = (A * F - C * D) / denom
    
    return (round(x, 2), round(y, 2))


def weighted_trilaterate(readings: List[Dict]) -> Optional[Tuple[float, float]]:
    """
    Trilateration with weighted averaging of recent readings.
    
    Uses SNR as weight (higher SNR = more reliable reading).
    """
    # Group by receiver
    by_receiver: Dict[str, List[Dict]] = {"A": [], "B": [], "C": []}
    
    for r in readings:
        rid = r.get("receiver_id", "")
        if rid in by_receiver:
            by_receiver[rid].append(r)
    
    # Calculate weighted average RSSI per receiver
    distances = {}
    
    for rid, rx_readings in by_receiver.items():
        if not rx_readings:
            continue
        
        # Weight by SNR (higher SNR = better signal quality)
        total_weight = 0
        weighted_rssi = 0
        
        for r in rx_readings:
            snr = max(r.get("snr", 1), 1)  # Minimum SNR of 1
            weight = snr
            weighted_rssi += r.get("rssi", -70) * weight
            total_weight += weight
        
        if total_weight > 0:
            avg_rssi = weighted_rssi / total_weight
            distances[rid] = rssi_to_distance(avg_rssi)
    
    return trilaterate(distances)


class PositionTracker:
    """Track tag position over time with smoothing."""
    
    def __init__(self, window_size: int = 5):
        self.window_size = window_size
        self.recent_readings: Dict[str, deque] = {
            "A": deque(maxlen=window_size),
            "B": deque(maxlen=window_size),
            "C": deque(maxlen=window_size),
        }
        self.position_history: deque = deque(maxlen=10)
    
    def add_reading(self, receiver_id: str, rssi: float, snr: float):
        """Add a new RSSI reading."""
        if receiver_id in self.recent_readings:
            self.recent_readings[receiver_id].append({
                "rssi": rssi,
                "snr": snr,
                "time": time.time()
            })
    
    def get_position(self) -> Optional[Tuple[float, float]]:
        """Calculate current position from recent readings."""
        distances = {}
        
        for rid, readings in self.recent_readings.items():
            if not readings:
                continue
            
            # Use median RSSI for robustness
            rssi_values = sorted([r["rssi"] for r in readings])
            median_rssi = rssi_values[len(rssi_values) // 2]
            
            distances[rid] = rssi_to_distance(median_rssi)
        
        position = trilaterate(distances)
        
        if position:
            self.position_history.append(position)
            
            # Smooth with moving average
            if len(self.position_history) >= 3:
                avg_x = sum(p[0] for p in self.position_history) / len(self.position_history)
                avg_y = sum(p[1] for p in self.position_history) / len(self.position_history)
                return (round(avg_x, 2), round(avg_y, 2))
        
        return position
    
    def get_distances(self) -> Dict[str, float]:
        """Get current estimated distances to each receiver."""
        distances = {}
        
        for rid, readings in self.recent_readings.items():
            if readings:
                rssi_values = sorted([r["rssi"] for r in readings])
                median_rssi = rssi_values[len(rssi_values) // 2]
                distances[rid] = rssi_to_distance(median_rssi)
        
        return distances
    
    def get_rssi_values(self) -> Dict[str, float]:
        """Get current RSSI values for each receiver."""
        rssi_vals = {}
        
        for rid, readings in self.recent_readings.items():
            if readings:
                rssi_values = sorted([r["rssi"] for r in readings])
                median_rssi = rssi_values[len(rssi_values) // 2]
                rssi_vals[rid] = median_rssi
        
        return rssi_vals


def process_csv_file(filepath: str, live: bool = False):
    """
    Process CSV file and calculate positions.
    
    Args:
        filepath: Path to CSV file with columns: timestamp_s, receiver_id, rssi_dbm, snr_db
        live: If True, keep watching file for new data
    """
    tracker = PositionTracker(window_size=5)
    
    print("\n" + "=" * 70)
    print("TRILATERATION POSITIONING")
    print("=" * 70)
    print(f"Receivers: A={RECEIVERS['A'].x},{RECEIVERS['A'].y}  "
          f"B={RECEIVERS['B'].x},{RECEIVERS['B'].y}  "
          f"C={RECEIVERS['C'].x},{RECEIVERS['C'].y}")
    print(f"Calibration: RSSI@1m={RSSI_AT_1M} dBm, Path Loss n={PATH_LOSS_N}")
    print("=" * 70)
    print()
    
    last_pos = 0
    
    while True:
        try:
            with open(filepath, 'r') as f:
                reader = csv.DictReader(f)
                rows = list(reader)
                
                # Process new rows
                for row in rows[last_pos:]:
                    rid = row.get('receiver_id', '')
                    rssi = float(row.get('rssi_dbm', row.get('rssi', -70)))
                    snr = float(row.get('snr_db', row.get('snr', 5)))
                    
                    tracker.add_reading(rid, rssi, snr)
                
                last_pos = len(rows)
                
                # Calculate position
                position = tracker.get_position()
                rssi_values = tracker.get_rssi_values()
                
                if position and rssi_values:
                    print(f"Position: ({position[0]:6.2f}, {position[1]:6.2f}) m  |  "
                          f"RSSI: A={rssi_values.get('A', 0):4.0f}dBm  "
                          f"B={rssi_values.get('B', 0):4.0f}dBm  "
                          f"C={rssi_values.get('C', 0):4.0f}dBm")
                
                if not live:
                    break
                    
        except FileNotFoundError:
            if live:
                print(f"Waiting for {filepath}...")
            else:
                print(f"ERROR: File not found: {filepath}")
                return
        except Exception as e:
            print(f"Error: {e}")
        
        if live:
            time.sleep(0.5)


def calibration_mode():
    """
    Interactive calibration helper.
    """
    print("\n" + "=" * 60)
    print("RSSI CALIBRATION MODE")
    print("=" * 60)
    print("""
To calibrate, you need to find the RSSI value at exactly 1 meter:

1. Place the TAG exactly 1 meter from a receiver
2. Collect several RSSI readings
3. Use the average as RSSI_AT_1M

Typical values:
  - Open area: -40 to -50 dBm
  - Indoor: -45 to -55 dBm
  - With obstacles: -50 to -65 dBm

Current setting: RSSI_AT_1M = {rssi_1m} dBm

To update, edit trilateration.py and change RSSI_AT_1M value.
""".format(rssi_1m=RSSI_AT_1M))
    
    # Distance calculator
    print("\nRSSI → Distance Calculator:")
    print("-" * 40)
    
    test_rssi = [-40, -45, -50, -55, -60, -65, -70, -75, -80]
    print(f"{'RSSI (dBm)':<12} {'Distance (m)':<12}")
    for rssi in test_rssi:
        dist = rssi_to_distance(rssi)
        print(f"{rssi:<12} {dist:<12.2f}")


def main():
    parser = argparse.ArgumentParser(description="Trilateration for LoRa Indoor Positioning")
    parser.add_argument("--input", "-i", help="Input CSV file (from mac_server.py)")
    parser.add_argument("--live", "-l", action="store_true", help="Live mode - watch file for updates")
    parser.add_argument("--calibrate", "-c", action="store_true", help="Calibration mode")
    parser.add_argument("--rssi-1m", type=float, help="Override RSSI at 1 meter")
    parser.add_argument("--path-loss", "-n", type=float, help="Override path loss exponent")
    
    args = parser.parse_args()
    
    # Override calibration values if provided
    global RSSI_AT_1M, PATH_LOSS_N
    if args.rssi_1m:
        RSSI_AT_1M = args.rssi_1m
    if args.path_loss:
        PATH_LOSS_N = args.path_loss
    
    if args.calibrate:
        calibration_mode()
    elif args.input:
        process_csv_file(args.input, live=args.live)
    else:
        parser.print_help()
        print("\n\nExample usage:")
        print("  python trilateration.py --calibrate")
        print("  python trilateration.py --input all_receivers.csv")
        print("  python trilateration.py --input all_receivers.csv --live")


if __name__ == "__main__":
    main()
