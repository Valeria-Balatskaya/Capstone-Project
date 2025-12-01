import serial, time, csv, re

PORT = "/dev/cu.usbserial-1110"   # RECEIVER
BAUD = 115200
OUT_CSV = "lora_rx_log.csv"

ser = serial.Serial(PORT, BAUD, timeout=1)

# Configure and start long RX test
ser.write(b"AT+TCONF=868300000:14:0:7:4/5:1:1:1:16:0:0:0\r\n")
time.sleep(0.5)
ser.read_all()
ser.write(b"AT+TRX=9999\r\n")
time.sleep(0.5)
ser.read_all()

pattern = re.compile(r"RssiValue=(-?\d+)\s*dBm,\s*SnrValue=(-?\d+)dB")

with open(OUT_CSV, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["timestamp_s", "rssi_dbm", "snr_db"])
    start = time.time()
    print("Logging to", OUT_CSV)
    while True:
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
            print(f"{t:.3f}s  RSSI={rssi} dBm  SNR={snr} dB")
