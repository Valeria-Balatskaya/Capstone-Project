import serial, time

PORT = "/dev/cu.usbserial-1120"   # TAG - MAKE SURE THIS IS THE SENDER BOARD!
BAUD = 115200

ser = serial.Serial(PORT, BAUD, timeout=1)

# Reset and configure radio
print("Resetting board...")
ser.write(b"ATZ\r\n")  # Reset the board
time.sleep(1)
ser.read_all()

print("Configuring radio for TX...")
ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
time.sleep(0.5)
print(ser.read_all().decode(errors="ignore"))

print(f"Sender running on {PORT}")
print("Transmitting packets every 7 seconds...")
print("-" * 40)

while True:
    ser.write(b"AT+TTX=10\r\n")   # send 10 packets
    print("Started TTX=10")
    time.sleep(5)                 # wait for TX to finish
    print(ser.read_all().decode(errors="ignore"))
    time.sleep(2)                 # pause between bursts
