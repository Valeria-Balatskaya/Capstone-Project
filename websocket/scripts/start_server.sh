#!/bin/bash
# macOS script to start WebSocket server

PORT=8765
RSSI_AT_1M=-40
PATH_LOSS=2.5

echo "=========================================="
echo "  LoRa WebSocket Server"
echo "=========================================="
echo "Port: $PORT"
echo "RSSI at 1m: $RSSI_AT_1M dBm"
echo "Path Loss: $PATH_LOSS"
echo ""

cd "$(dirname "$0")/.."
python3 server_ws.py \
    --port "$PORT" \
    --rssi-1m "$RSSI_AT_1M" \
    --path-loss "$PATH_LOSS"
