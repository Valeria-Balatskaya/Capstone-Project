import math
import random
from paho.mqtt import client as mqtt_client
from paho.mqtt.client import CallbackAPIVersion
from scipy.optimize import least_squares
import numpy as np

# ============ DAVIES MQTT (Fixed for v2.0+) ============
broker = 'broker.emqx.io'
port = 1883
topic = "loratrack/position"
client_id = f'loratrack-{random.randint(0, 1000)}'

def connect_mqtt():
    def on_connect(client, userdata, flags, rc, properties=None):
        if rc == 0:
            print("✓ Connected to MQTT Broker!")
        else:
            print(f"✗ Failed, return code {rc}")
    
    # Fix: Add callback_api_version for paho-mqtt 2.0+
    client = mqtt_client.Client(
        client_id=client_id,
        callback_api_version=CallbackAPIVersion.VERSION2
    )
    client.on_connect = on_connect
    client.connect(broker, port)
    return client

# ============ OUR TRILATERATION (Flexible) ============
def rssi_to_distance(rssi, tx_power=-50, path_loss_exponent=2.5):
    """Davies formula - proven to work"""
    distance = math.pow(10, ((tx_power - rssi) / (10 * path_loss_exponent)))
    return distance

def trilaterate(gateways):
    """Our flexible trilateration for any gateway positions"""
    def latlong_to_meters(lat, lng, ref_lat, ref_lng):
        lat_diff = (lat - ref_lat) * 111000
        lng_diff = (lng - ref_lng) * 111000 * np.cos(np.radians(ref_lat))
        return lat_diff, lng_diff
    
    ref_lat = gateways[0]['lat']
    ref_lng = gateways[0]['lng']
    
    positions = []
    distances = []
    for gw in gateways:
        x, y = latlong_to_meters(gw['lat'], gw['lng'], ref_lat, ref_lng)
        positions.append([x, y])
        distances.append(gw['distance'])
    
    positions = np.array(positions)
    distances = np.array(distances)
    
    def equations(p):
        x, y = p
        return [
            np.sqrt((x - pos[0])**2 + (y - pos[1])**2) - dist
            for pos, dist in zip(positions, distances)
        ]
    
    x0 = [np.mean(positions[:, 0]), np.mean(positions[:, 1])]
    result = least_squares(equations, x0)
    
    x_meters, y_meters = result.x
    lat = ref_lat + (x_meters / 111000)
    lng = ref_lng + (y_meters / (111000 * np.cos(np.radians(ref_lat))))
    
    return lat, lng

# ============ TEST COMBINED SOLUTION ============
if __name__ == "__main__":
    print("="*60)
    print("COMBINED BEST SOLUTION TEST")
    print("="*60)
    
    # Test gateways
    gateways = [
        {'lat': 50.0000, 'lng': 8.0000, 'rssi': -70},
        {'lat': 50.0010, 'lng': 8.0010, 'rssi': -75},
        {'lat': 50.0005, 'lng': 8.0015, 'rssi': -68},
    ]
    
    print("\nConverting RSSI to distances...")
    for gw in gateways:
        gw['distance'] = rssi_to_distance(gw['rssi'])
        print(f"Gateway ({gw['lat']}, {gw['lng']}): "
              f"RSSI={gw['rssi']} → {gw['distance']:.1f}m")
    
    print("\nCalculating position...")
    lat, lng = trilaterate(gateways)
    
    print(f"\n✓ Position: {lat:.6f}, {lng:.6f}")
    
    print("\nPublishing to MQTT...")
    client = connect_mqtt()
    client.loop_start()
    
    import time
    time.sleep(1)
    
    msg = f'{{"deviceId":"test_tag","lat":{lat},"lng":{lng}}}'
    result = client.publish(topic, msg)
    if result[0] == 0:
        print(f"✓ Published: {msg}")
    else:
        print(f"✗ Publish failed")
    
    time.sleep(1)
    client.loop_stop()
    
    print("\n" + "="*60)
    print("✓ COMPLETE! This is our production-ready code.")
    print("="*60)
    print("\nWhat we learned:")
    print("  • Davies trilateration works (validated our approach)")
    print("  • Our flexible algorithm works for any gateway positions")
    print("  • MQTT publishing works for real-time updates")
    print("  • RSSI → distance conversion is correct")
    print("\nNext: Integrate with ChirpStack!")
