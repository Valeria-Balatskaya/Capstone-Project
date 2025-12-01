#!/usr/bin/env python3
"""
Diagnostic script to test each board individually.
Run this to identify which port is which board.
"""
import serial
import serial.tools.list_ports
import time
import sys

def test_port(port):
    """Test a single port to see what board is connected."""
    print(f"\n{'='*50}")
    print(f"Testing: {port}")
    print('='*50)
    
    try:
        ser = serial.Serial(port, 115200, timeout=2)
        time.sleep(0.5)
        
        # Clear buffer
        ser.read_all()
        
        # Send AT command to check if board responds
        ser.write(b"AT\r\n")
        time.sleep(0.3)
        response = ser.read_all().decode(errors='ignore')
        print(f"AT response: {response.strip()}")
        
        # Reset to clear any previous state
        ser.write(b"ATZ\r\n")
        time.sleep(1)
        ser.read_all()
        
        # Get device info
        ser.write(b"AT+VER\r\n")
        time.sleep(0.3)
        response = ser.read_all().decode(errors='ignore')
        print(f"Version: {response.strip()}")
        
        ser.close()
        return True
        
    except Exception as e:
        print(f"Error: {e}")
        return False


def main():
    print("LoRa Board Diagnostic Tool")
    print("="*50)
    
    # List all ports
    ports = serial.tools.list_ports.comports()
    usb_ports = [p.device for p in ports if 'usb' in p.device.lower()]
    
    print(f"\nFound {len(usb_ports)} USB serial ports:")
    for p in usb_ports:
        print(f"  - {p}")
    
    if not usb_ports:
        print("No USB serial ports found!")
        return
    
    # Test each port
    for port in usb_ports:
        test_port(port)
    
    print("\n" + "="*50)
    print("MANUAL TEST INSTRUCTIONS")
    print("="*50)
    print("""
To test sender/receiver communication:

1. Open 2 terminal windows

2. TERMINAL 1 - Start a receiver on ONE port:
   screen /dev/cu.usbserial-XXXX 115200
   Then type:
   AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0
   AT+TRX=9999
   
3. TERMINAL 2 - Start sender on ANOTHER port:
   screen /dev/cu.usbserial-YYYY 115200
   Then type:
   AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0
   AT+TTX=10

4. Watch TERMINAL 1 - you should see:
   RssiValue=-XX dBm, SnrValue=XX dB

If you see OnRxTimeout instead, the boards can't hear each other.

Possible causes:
- Antennas not connected
- Wrong frequency (868 vs 915 MHz region)
- Boards too close together (interference)
- Boards too far apart
- Different LoRa parameters
""")


if __name__ == "__main__":
    main()
