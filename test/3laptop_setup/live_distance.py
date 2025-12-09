#!/usr/bin/env python3
"""
LIVE DISTANCE MONITOR - Real-time tag tracking
===============================================
Shows live distances from all 3 receivers as tag moves.

Usage:
    python live_distance.py --input all_receivers.csv
    python live_distance.py --input all_receivers.csv --rssi-1m -15

Calibration:
    1. Place tag exactly 1 meter from a receiver
    2. Note the RSSI value shown
    3. Use that as --rssi-1m value
"""

import argparse
import csv
import time
from collections import deque
from datetime import datetime


# ============================================================
# CALIBRATION - MEASURE AND ADJUST!
# ============================================================

# RSSI at exactly 1 meter distance (calibrate this!)
# Based on your data, try values between -10 and -20
RSSI_AT_1M = -15  

# Path loss exponent: 2.0=open space, 2.5=indoor, 3.0+=walls
PATH_LOSS_N = 2.5

# ============================================================


def rssi_to_distance(rssi: float, rssi_1m: float = RSSI_AT_1M, n: float = PATH_LOSS_N) -> float:
    """
    Convert RSSI to distance using log-distance path loss model.
    
    Formula: distance = 10 ^ ((RSSI_1m - RSSI) / (10 * n))
    """
    if rssi >= rssi_1m:
        return 0.1  # Very close
    
    distance = 10 ** ((rssi_1m - rssi) / (10 * n))
    return distance


def clear_screen():
    """Clear terminal screen."""
    os.system('cls' if os.name == 'nt' else 'clear')


def main():
    parser = argparse.ArgumentParser(description="Live Distance Monitor - Track tag in real-time")
    parser.add_argument("--input", "-i", required=True, help="Input CSV file (from mac_server.py)")
    parser.add_argument("--rssi-1m", type=float, default=RSSI_AT_1M, help=f"RSSI at 1m (default: {RSSI_AT_1M})")
    parser.add_argument("--path-loss", "-n", type=float, default=PATH_LOSS_N, help=f"Path loss n (default: {PATH_LOSS_N})")
    args = parser.parse_args()
    
    rssi_1m = args.rssi_1m
    n = args.path_loss
    
    # Store recent readings per receiver (for smoothing)
    readings = {
        "A": deque(maxlen=3),
        "B": deque(maxlen=3),
        "C": deque(maxlen=3)
    }
    
    last_row = 0
    
    print("\n" + "=" * 75)
    print("LIVE DISTANCE MONITOR - Tag Tracking")
    print("=" * 75)
    print(f"Calibration: RSSI@1m = {rssi_1m} dBm, Path Loss n = {n}")
    print("-" * 75)
    print(f"{'Time':<10} {'Receiver A':<20} {'Receiver B':<20} {'Receiver C':<20}")
    print(f"{'':10} {'RSSI → Distance':<20} {'RSSI → Distance':<20} {'RSSI → Distance':<20}")
    print("=" * 75)
    
    while True:
        try:
            with open(args.input, 'r') as f:
                reader = csv.DictReader(f)
                rows = list(reader)
                
                # Process new rows only
                new_data = False
                for row in rows[last_row:]:
                    rid = row.get('receiver_id', '')
                    
                    try:
                        rssi = float(row.get('rssi_dbm', row.get('rssi', -70)))
                    except:
                        continue
                    
                    if rid in readings:
                        readings[rid].append(rssi)
                        new_data = True
                
                last_row = len(rows)
                
                # Only print when we have new data
                if new_data:
                    now = datetime.now().strftime("%H:%M:%S")
                    output = f"{now:<10}"
                    
                    for rid in ["A", "B", "C"]:
                        if readings[rid]:
                            # Use median for stability
                            rssi_list = sorted(readings[rid])
                            rssi = rssi_list[len(rssi_list) // 2]
                            dist = rssi_to_distance(rssi, rssi_1m, n)
                            output += f"{rssi:4.0f}dBm → {dist:5.2f}m      "
                        else:
                            output += f"  --dBm →   --m      "
                    
                    print(output)
                    
        except FileNotFoundError:
            print(f"Waiting for {args.input}...")
        except Exception as e:
            print(f"Error: {e}")
        
        time.sleep(0.3)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nStopped.")
