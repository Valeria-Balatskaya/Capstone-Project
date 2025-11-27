#!/bin/bash
# macOS script to start visualizer

ROOM_WIDTH=10
ROOM_HEIGHT=10

echo "=========================================="
echo "  LoRa Position Visualizer"
echo "=========================================="
echo "Room: ${ROOM_WIDTH}m x ${ROOM_HEIGHT}m"
echo ""

cd "$(dirname "$0")/.."
python3 visualizer_mqtt.py \
    --mqtt-host localhost \
    --width "$ROOM_WIDTH" \
    --height "$ROOM_HEIGHT"
