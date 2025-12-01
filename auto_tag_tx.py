import serial, time

PORT = "/dev/cu.usbserial-1120"   # TAG
BAUD = 115200

ser = serial.Serial(PORT, BAUD, timeout=1)

# Configure radio once
ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
time.sleep(0.5)
print(ser.read_all().decode(errors="ignore"))

while True:
    ser.write(b"AT+TTX=10\r\n")   # send 10 packets
    print("Started TTX=10")
    time.sleep(5)                 # wait for TX to finish
    print(ser.read_all().decode(errors="ignore"))
    time.sleep(2)                 # pause between bursts
