import socket
import json
import time
import random
from datetime import datetime

# Single gateway configuration
GATEWAY = {
    "id": "b827ebfffe000001",
    "name": "TestAnchor-01",
    "lat": 52.3676,
    "lon": 4.9041,
    "alt": 10
}

SERVER_HOST = "localhost"
SERVER_PORT = 1700

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

def send_stat():
    """Send gateway statistics"""
    stat_data = bytearray([0x02])
    token = random.randint(0, 65535).to_bytes(2, 'big')
    stat_data.extend(token)
    stat_data.extend([0x00])
    stat_data.extend(bytes.fromhex(GATEWAY["id"]))
    
    stat = {
        "stat": {
            "time": datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S GMT"),
            "lati": GATEWAY["lat"],
            "long": GATEWAY["lon"],
            "alti": GATEWAY["alt"],
            "rxnb": 10,
            "rxok": 10,
            "rxfw": 10,
            "ackr": 100.0,
            "dwnb": 0,
            "txnb": 0
        }
    }
    
    stat_data.extend(json.dumps(stat).encode())
    sock.sendto(stat_data, (SERVER_HOST, SERVER_PORT))
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Sent STAT")

def send_pull():
    """Send PULL_DATA"""
    pull_data = bytearray([0x02])
    token = random.randint(0, 65535).to_bytes(2, 'big')
    pull_data.extend(token)
    pull_data.extend([0x02])
    pull_data.extend(bytes.fromhex(GATEWAY["id"]))
    
    sock.sendto(pull_data, (SERVER_HOST, SERVER_PORT))
    print(f"[{datetime.now().strftime('%H:%M:%S')}] Sent PULL_DATA")

print("=" * 60)
print("SIMPLE SINGLE-GATEWAY SIMULATOR")
print("=" * 60)
print(f"Gateway: {GATEWAY['name']}")
print(f"ID: {GATEWAY['id']}")
print(f"Location: ({GATEWAY['lat']}, {GATEWAY['lon']})")
print("=" * 60)
print("\nStarting...\n")

try:
    while True:
        send_pull()
        time.sleep(5)
        send_stat()
        time.sleep(25)
except KeyboardInterrupt:
    print("\n\nStopped")
    sock.close()
