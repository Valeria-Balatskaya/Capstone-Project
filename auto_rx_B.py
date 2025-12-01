import serial, time, csv, re, os
import sys

# Auto-detect OS and set port accordingly
# Windows: COM5, COM7, etc.  |  Mac: /dev/cu.usbserial-XX
if sys.platform == "win32":
    PORT = "COM7"  # Change to COM5 or COM7 depending on which receiver
else:
    PORT = "/dev/cu.usbserial-10"  # Mac port

BAUD = 115200
OUT_CSV = os.path.join(os.path.dirname(__file__), "rx_B.csv")

ser = serial.Serial(PORT, BAUD, timeout=1)

# Configure radio
ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
time.sleep(0.5)
ser.read_all()

# Start receiving
ser.write(b"AT+TRX=9999\r\n")
time.sleep(0.5)
ser.read_all()

pattern = re.compile(r"RssiValue=(-?\d+)\s*dBm,\s*SnrValue=(-?\d+)dB")

with open(OUT_CSV, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["timestamp_s", "rssi_dbm", "snr_db"])
    start = time.time()
    print(f"Logging from {PORT} to {OUT_CSV}")
    
    while True:
        try:
            line = ser.readline().decode(errors="ignore").strip()
            if not line:
                continue
            m = pattern.search(line)
            if m:
                t = time.time() - start
                rssi = int(m.group(1))
                snr = int(m.group(2))
                writer.writerow([f"{t:.3f}", rssi, snr])
                f.flush()
                print(f"RX_B: {t:.3f}s  RSSI={rssi} dBm  SNR={snr} dB")
        except KeyboardInterrupt:
            break
