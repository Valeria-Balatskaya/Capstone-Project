#!/usr/bin/env python3
import json
import paho.mqtt.client as mqtt
import time
import random
from datetime import datetime

client = mqtt.Client(client_id="simulator", clean_session=True)
client.connect("localhost", 1883, keepalive=60)

device_eui = "0123456789abcdef"
device_name = "Mobile Tag 01"

print(f"Sending 10 test messages from {device_name}...")
print(f"Using 3 gateways: GW-001, GW-002, GW-003\n")

for i in range(10):
    rx_info = [
        {"gatewayId": "aabbccddeeff0001", "rssi": -87 + random.randint(-5, 5), "snr": 7.5},
        {"gatewayId": "aabbccddeeff0002", "rssi": -92 + random.randint(-5, 5), "snr": 5.2},
        {"gatewayId": "aabbccddeeff0003", "rssi": -95 + random.randint(-5, 5), "snr": 3.1},
    ]
    
    payload = {
        "deviceName": device_name,
        "deviceEUI": device_eui,
        "time": datetime.utcnow().isoformat() + "Z",
        "rxInfo": rx_info
    }
    
    topic = f"application/1/device/{device_eui}/event/up"
    client.publish(topic, json.dumps(payload))
    
    print(f"  [{i+1}/10] Sent message from {device_name}")
    time.sleep(1)

client.disconnect()
print("\n✓ Test complete!")
