#!/bin/bash
# macOS script to start MQTT central processor

MQTT_HOST="localhost"
RSSI_AT_1M=-40
PATH_LOSS=2.5

echo "=========================================="
echo "  LoRa MQTT Central Processor"
echo "=========================================="
echo "MQTT Host: $MQTT_HOST"
echo "RSSI at 1m: $RSSI_AT_1M dBm"
echo "Path Loss: $PATH_LOSS"
echo ""

cd "$(dirname "$0")/.."
python3 processor_mqtt.py \
    --mqtt-host "$MQTT_HOST" \
    --rssi-1m "$RSSI_AT_1M" \
    --path-loss "$PATH_LOSS"
