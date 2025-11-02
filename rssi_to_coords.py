import math

# ============================================
# RSSI TO DISTANCE CONVERTER
# ============================================

def rssi_to_distance(rssi, tx_power=-20, n=3.0):
    """
    Convert RSSI to distance using log-distance path loss model
    
    Formula: d = 10 ^ ((TxPower - RSSI) / (10 * n))
    
    Parameters:
    - rssi: Received Signal Strength (dBm) - from your receiver
    - tx_power: Transmission power (dBm) - default -20 for LoRa
    - n: Path loss exponent (2.0-4.0) - depends on environment
        2.0 = free space (outdoor)
        3.0 = indoor with light walls
        3.5 = indoor with thick walls
    
    Returns:
    - distance in meters
    """
    distance = 10 ** ((tx_power - rssi) / (10 * n))
    return distance


# ============================================
# TRILATERATION - RSSI TO X,Y COORDINATES
# ============================================

def trilateration(anchor1, anchor2, anchor3, d1, d2, d3):
    """
    Calculate X,Y coordinates from 3 anchors and distances
    
    Parameters:
    - anchor1: [x1, y1] coordinates of anchor 1
    - anchor2: [x2, y2] coordinates of anchor 2  
    - anchor3: [x3, y3] coordinates of anchor 3
    - d1, d2, d3: distances from each anchor (meters)
    
    Returns:
    - [x, y] coordinates of tag
    """
    x1, y1 = anchor1
    x2, y2 = anchor2
    x3, y3 = anchor3
    
    A = 2*x2 - 2*x1
    B = 2*y2 - 2*y1
    C = d1**2 - d2**2 - x1**2 + x2**2 - y1**2 + y2**2
    D = 2*x3 - 2*x2
    E = 2*y3 - 2*y2
    F = d2**2 - d3**2 - x2**2 + x3**2 - y2**2 + y3**2
    
    # Solve system of equations
    try:
        x = (C*E - F*B) / (E*A - B*D)
        y = (C*D - A*F) / (B*D - A*E)
        return [x, y]
    except ZeroDivisionError:
        return None


# ============================================
# MAIN INTERFACE
# ============================================

print("=" * 70)
print("RSSI TO COORDINATES CONVERTER")
print("=" * 70)
print()

# Example 1: Single anchor - Distance only
print("=" * 70)
print("EXAMPLE 1: SINGLE ANCHOR (Distance Only)")
print("=" * 70)
print()
print("You have 1 anchor (receiver). You can only calculate DISTANCE.")
print()

# Your actual RSSI values
rssi_values = [-38, -31, -35, -46, -34]  # From your screenshot
print(f"Your RSSI values: {rssi_values}")
print()

for rssi in rssi_values:
    dist = rssi_to_distance(rssi, tx_power=-20, n=3.0)
    print(f"  RSSI {rssi} dBm → Distance: {dist:.2f} m ({dist*100:.0f} cm)")

print()
print("⚠️  With 1 anchor, you only know the tag is somewhere on a CIRCLE")
print("    around the anchor at this distance. Cannot determine X,Y!")
print()

# Example 2: Three anchors - X,Y coordinates
print("=" * 70)
print("EXAMPLE 2: THREE ANCHORS (X,Y Coordinates)")
print("=" * 70)
print()
print("When you have 3+ anchors, you can calculate X,Y coordinates!")
print()

# Define anchor positions (example room: 10m x 10m)
anchor1_pos = [0, 0]      # Bottom-left corner
anchor2_pos = [10, 0]     # Bottom-right corner
anchor3_pos = [5, 10]     # Top-middle

print(f"Anchor 1 position: {anchor1_pos} (Bottom-Left)")
print(f"Anchor 2 position: {anchor2_pos} (Bottom-Right)")
print(f"Anchor 3 position: {anchor3_pos} (Top-Middle)")
print()

# Example RSSI values from each anchor
rssi1 = -65  # From anchor 1
rssi2 = -70  # From anchor 2
rssi3 = -75  # From anchor 3

# Convert RSSI to distances
dist1 = rssi_to_distance(rssi1, n=3.0)
dist2 = rssi_to_distance(rssi2, n=3.0)
dist3 = rssi_to_distance(rssi3, n=3.0)

print(f"RSSI from Anchor 1: {rssi1} dBm → Distance: {dist1:.2f} m")
print(f"RSSI from Anchor 2: {rssi2} dBm → Distance: {dist2:.2f} m")
print(f"RSSI from Anchor 3: {rssi3} dBm → Distance: {dist3:.2f} m")
print()

# Calculate position
position = trilateration(anchor1_pos, anchor2_pos, anchor3_pos, 
                         dist1, dist2, dist3)

if position:
    print(f"✅ Calculated Tag Position: X={position[0]:.2f} m, Y={position[1]:.2f} m")
else:
    print("❌ Cannot calculate position - anchors might be collinear")

print()

# ============================================
# INTERACTIVE MODE
# ============================================

print("=" * 70)
print("INTERACTIVE MODE - YOUR DATA")
print("=" * 70)
print()

while True:
    print("\nChoose mode:")
    print("  1 - Calculate distance from RSSI (1 anchor)")
    print("  2 - Calculate X,Y from 3 RSSI values (3 anchors)")
    print("  q - Quit")
    
    choice = input("\nYour choice: ").strip()
    
    if choice == 'q':
        break
    
    elif choice == '1':
        try:
            rssi = float(input("Enter RSSI (dBm): "))
            n = float(input("Path loss exponent (2.0-4.0, default 3.0): ") or 3.0)
            
            distance = rssi_to_distance(rssi, tx_power=-20, n=n)
            
            print(f"\n  📏 Distance: {distance:.2f} m ({distance*100:.0f} cm)")
            print(f"  ⚠️  Tag is somewhere on a circle of radius {distance:.2f}m")
            print(f"      around the anchor. Need 3 anchors for exact position!")
            
        except ValueError:
            print("❌ Invalid input!")
    
    elif choice == '2':
        try:
            print("\nEnter anchor positions (meters):")
            x1 = float(input("  Anchor 1 X: "))
            y1 = float(input("  Anchor 1 Y: "))
            x2 = float(input("  Anchor 2 X: "))
            y2 = float(input("  Anchor 2 Y: "))
            x3 = float(input("  Anchor 3 X: "))
            y3 = float(input("  Anchor 3 Y: "))
            
            print("\nEnter RSSI from each anchor (dBm):")
            rssi1 = float(input("  RSSI from Anchor 1: "))
            rssi2 = float(input("  RSSI from Anchor 2: "))
            rssi3 = float(input("  RSSI from Anchor 3: "))
            
            n = float(input("Path loss exponent (default 3.0): ") or 3.0)
            
            # Convert RSSI to distances
            d1 = rssi_to_distance(rssi1, n=n)
            d2 = rssi_to_distance(rssi2, n=n)
            d3 = rssi_to_distance(rssi3, n=n)
            
            print(f"\nDistances:")
            print(f"  From Anchor 1: {d1:.2f} m")
            print(f"  From Anchor 2: {d2:.2f} m")
            print(f"  From Anchor 3: {d3:.2f} m")
            
            # Calculate position
            pos = trilateration([x1,y1], [x2,y2], [x3,y3], d1, d2, d3)
            
            if pos:
                print(f"\n✅ TAG POSITION:")
                print(f"   X = {pos[0]:.2f} m")
                print(f"   Y = {pos[1]:.2f} m")
            else:
                print("\n❌ Cannot calculate - check anchor positions!")
                
        except ValueError:
            print("❌ Invalid input!")

print("\nBye!")
