#!/usr/bin/env python3
"""
TEST: Example Sender Board Configuration
=========================================
This file shows example AT commands to configure a Wio-E5 as a sender.
Run these commands via serial terminal (e.g., screen, minicom, or PuTTY).

This is NOT a Python script to run - it's documentation of AT commands.
"""

# ============================================================================
# SENDER BOARD SETUP (Connect to sender board via serial terminal)
# ============================================================================

SENDER_AT_COMMANDS = """
# 1. Test connection
AT

# 2. Set to test mode
AT+MODE=TEST

# 3. Configure LoRa parameters (must match receiver)
AT+TEST=RFCFG,868,SF7,125,12,15,14,ON,OFF,OFF

# Parameters explained:
#   868     = Frequency in MHz (use 915 for US, 868 for EU)
#   SF7     = Spreading Factor (7-12, lower = faster but shorter range)
#   125     = Bandwidth in kHz
#   12      = Coding Rate (4/5 to 4/8)
#   15      = Preamble length
#   14      = TX Power in dBm
#   ON      = CRC enabled
#   OFF     = IQ inversion off
#   OFF     = Public network off

# 4. Send a test message (hex encoded)
# "HELLO" = 48454C4C4F in hex
AT+TEST=TXLRPKT,"48454C4C4F"

# 5. Send with your tag ID (e.g., "TAG001" = 544147303031)
AT+TEST=TXLRPKT,"544147303031"

# 6. To send continuously, you can use a loop in your code
# or create a simple Arduino/MicroPython script on the sender board
"""

# ============================================================================
# RECEIVER BOARD SETUP (The receiver_server.py handles this automatically)
# ============================================================================

RECEIVER_AT_COMMANDS = """
# 1. Test connection
AT

# 2. Set to test mode
AT+MODE=TEST

# 3. Configure LoRa parameters (must match sender!)
AT+TEST=RFCFG,868,SF7,125,12,15,14,ON,OFF,OFF

# 4. Start continuous receive mode
AT+TEST=RXLRPKT

# The board will now output received packets like:
# +RX "48454C4C4F",-45,12
# Where:
#   48454C4C4F = Received payload in hex
#   -45 = RSSI in dBm
#   12 = SNR
"""

# ============================================================================
# SIMPLE SENDER SCRIPT (If you want to automate sending)
# ============================================================================

SENDER_SCRIPT = '''
#!/usr/bin/env python3
"""
Simple LoRa Sender Script
Run this on the sender board's host computer to send periodic messages.
"""
import serial
import time
import sys

# Configuration
SERIAL_PORT = "/dev/cu.usbserial-XXXX"  # Change to your port
BAUD_RATE = 115200
TAG_ID = "TAG001"  # Your tag identifier
SEND_INTERVAL = 2  # Seconds between sends

def hex_encode(text):
    """Convert text to hex string."""
    return text.encode().hex().upper()

def main():
    try:
        ser = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        print(f"Connected to {SERIAL_PORT}")
        
        # Initialize
        time.sleep(1)
        ser.write(b"AT+MODE=TEST\\r\\n")
        time.sleep(0.5)
        ser.write(b"AT+TEST=RFCFG,868,SF7,125,12,15,14,ON,OFF,OFF\\r\\n")
        time.sleep(0.5)
        
        print(f"Sending as {TAG_ID} every {SEND_INTERVAL}s...")
        print("Press Ctrl+C to stop")
        
        payload_hex = hex_encode(TAG_ID)
        count = 0
        
        while True:
            cmd = f'AT+TEST=TXLRPKT,"{payload_hex}"\\r\\n'
            ser.write(cmd.encode())
            count += 1
            print(f"[{count}] Sent: {TAG_ID}")
            time.sleep(SEND_INTERVAL)
            
    except serial.SerialException as e:
        print(f"Serial error: {e}")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\\nStopped.")
        ser.close()

if __name__ == "__main__":
    main()
'''

if __name__ == "__main__":
    print("=" * 60)
    print("  LoRa Sender/Receiver AT Command Reference")
    print("=" * 60)
    print()
    print("SENDER BOARD COMMANDS:")
    print("-" * 60)
    print(SENDER_AT_COMMANDS)
    print()
    print("RECEIVER BOARD COMMANDS:")
    print("-" * 60)
    print(RECEIVER_AT_COMMANDS)
    print()
    print("=" * 60)
    print("To use the automated sender script, copy the SENDER_SCRIPT")
    print("content to a new file and modify the SERIAL_PORT setting.")
    print("=" * 60)
