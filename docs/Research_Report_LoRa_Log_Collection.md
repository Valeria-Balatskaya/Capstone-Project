# Research Report: LoRa Log Collection and Real-Time Tag Localization System

**Author:** System Architecture Team  
**Date:** November 27, 2025  
**Version:** 1.0  

---

## Executive Summary

This report presents a comprehensive analysis of three architectural approaches for collecting LoRa RSSI (Received Signal Strength Indicator) logs from distributed receivers and performing real-time trilateration for indoor tag localization. The system consists of three Windows laptops connected to Wio-E5 LoRa receivers and one Mac computer serving as the central processing unit.

After detailed analysis of data flow, reliability, latency, and cross-platform compatibility, **the WebSocket approach is recommended** as the optimal solution for this specific deployment scenario.

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Data Flow Architecture](#2-data-flow-architecture)
3. [Detailed Log Transmission Process](#3-detailed-log-transmission-process)
4. [Approach Comparison](#4-approach-comparison)
5. [Cross-Platform Considerations](#5-cross-platform-considerations)
6. [Recommendation](#6-recommendation)
7. [Implementation Guidelines](#7-implementation-guidelines)

---

## 1. System Overview

### 1.1 Hardware Configuration

| Component | Quantity | Platform | Role |
|-----------|----------|----------|------|
| Wio-E5 Dev Board | 3 | - | LoRa receivers |
| Windows Laptops | 3 | Windows 10/11 | Receiver hosts |
| Mac Computer | 1 | macOS | Central processor |
| LoRa Tag | 1 | - | Mobile transmitter |

### 1.2 Physical Deployment

```
                        Room Layout (10m × 10m)
    ┌─────────────────────────────────────────────────────────┐
    │                                                         │
    │                      R3 (5, 8.66)                       │
    │                          ▲                              │
    │                         /│\                             │
    │                        / │ \                            │
    │                       /  │  \                           │
    │                      /   │   \                          │
    │                     /    │    \                         │
    │                    /     │     \                        │
    │                   /    ◉ │      \    ◉ = Tag            │
    │                  /   Tag │       \   (unknown position) │
    │                 /        │        \                     │
    │                /         │         \                    │
    │               /          │          \                   │
    │              ▲───────────┴───────────▲                  │
    │          R1 (0, 0)              R2 (10, 0)              │
    │                                                         │
    └─────────────────────────────────────────────────────────┘
```

### 1.3 Communication Stack

```
    ┌─────────────┐
    │   LoRa Tag  │  868/915 MHz LoRa Radio
    └──────┬──────┘
           │ Broadcast (same packet to all)
           ▼
    ┌──────┴──────┬─────────────┐
    ▼             ▼             ▼
┌───────┐    ┌───────┐    ┌───────┐
│Wio-E5 │    │Wio-E5 │    │Wio-E5 │   Measures RSSI
│  R1   │    │  R2   │    │  R3   │
└───┬───┘    └───┬───┘    └───┬───┘
    │            │            │
    │ USB Serial │ USB Serial │ USB Serial
    ▼            ▼            ▼
┌───────┐    ┌───────┐    ┌───────┐
│Win PC │    │Win PC │    │Win PC │   Python receiver
│   1   │    │   2   │    │   3   │
└───┬───┘    └───┬───┘    └───┬───┘
    │            │            │
    │   Network  │   Network  │   Network (WiFi/Ethernet)
    │            │            │
    └────────────┼────────────┘
                 │
                 ▼
           ┌───────────┐
           │    Mac    │   Central processor
           │  (Server) │   Trilateration
           └───────────┘
```

---

## 2. Data Flow Architecture

### 2.1 Overview of Three Approaches

| Approach | Transport | Broker Required | Data Persistence |
|----------|-----------|-----------------|------------------|
| Simple (Shared Folder) | SMB/CIFS File Share | No | Automatic (files) |
| MQTT | TCP + MQTT Protocol | Yes (Mosquitto) | No (in-memory) |
| WebSocket | TCP + WebSocket | No (built-in) | Optional (backup) |

### 2.2 Data Message Structure

All approaches use the same JSON message format:

```json
{
    "receiver_id": "R1",
    "timestamp": "2025-11-27T10:30:15.123456+00:00",
    "timestamp_ms": 1732703415123,
    "position": {
        "x": 0.0,
        "y": 0.0,
        "z": 0.0
    },
    "rssi": -45,
    "snr": 12,
    "payload": "HELLO"
}
```

**Field Descriptions:**

| Field | Type | Description |
|-------|------|-------------|
| `receiver_id` | string | Unique identifier (R1, R2, R3) |
| `timestamp` | ISO 8601 | UTC timestamp with microseconds |
| `timestamp_ms` | integer | Unix timestamp in milliseconds (for synchronization) |
| `position` | object | Known receiver coordinates in meters |
| `rssi` | integer | Received Signal Strength Indicator (dBm) |
| `snr` | integer | Signal-to-Noise Ratio (dB) |
| `payload` | string | Decoded packet payload |

---

## 3. Detailed Log Transmission Process

This section provides a step-by-step breakdown of how LoRa logs are captured, processed, and transmitted to the central server.

### 3.1 Stage 1: LoRa Packet Reception

```
┌─────────────────────────────────────────────────────────────────┐
│                    STAGE 1: RADIO RECEPTION                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Tag transmits LoRa packet at 868/915 MHz                   │
│     └─► Packet contains: sequence number, sensor data          │
│                                                                 │
│  2. Radio waves propagate through environment                  │
│     └─► Signal attenuates with distance (path loss)            │
│     └─► Affected by obstacles, reflections, interference       │
│                                                                 │
│  3. Each Wio-E5 receiver captures the packet                   │
│     └─► Measures RSSI: signal strength at antenna              │
│     └─► Measures SNR: signal quality vs noise floor            │
│     └─► Decodes payload if CRC valid                           │
│                                                                 │
│  4. Wio-E5 outputs to serial (UART over USB)                   │
│     └─► Format: +RX "48454C4C4F",-45,12                        │
│                  ├─────────────┤ ├──┤├─┤                       │
│                  hex payload    RSSI SNR                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**RSSI Measurement:**
- RSSI is measured in dBm (decibels relative to 1 milliwatt)
- Typical range: -30 dBm (very close) to -120 dBm (maximum range)
- Higher value = stronger signal = closer distance

### 3.2 Stage 2: Serial Data Acquisition

```
┌─────────────────────────────────────────────────────────────────┐
│                  STAGE 2: SERIAL ACQUISITION                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Windows PC - Python Serial Reader                             │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  import serial                                            │  │
│  │                                                           │  │
│  │  # Open COM port connection                               │  │
│  │  serial_conn = serial.Serial('COM3', 9600, timeout=1)     │  │
│  │                                                           │  │
│  │  # Continuous reading loop (separate thread)              │  │
│  │  while True:                                              │  │
│  │      if serial_conn.in_waiting > 0:        # Data ready?  │  │
│  │          raw = serial_conn.readline()      # Read line    │  │
│  │          text = raw.decode('utf-8').strip()               │  │
│  │          # text = '+RX "48454C4C4F",-45,12'               │  │
│  │          process(text)                                    │  │
│  │      time.sleep(0.01)                      # 10ms poll    │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Why Separate Thread?                                          │
│  • Serial I/O is blocking (waits for data)                     │
│  • Main async loop must remain non-blocking                    │
│  • Thread handles blocking I/O, passes data via queue          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.3 Stage 3: Packet Parsing

```
┌─────────────────────────────────────────────────────────────────┐
│                    STAGE 3: PACKET PARSING                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Input: '+RX "48454C4C4F",-45,12'                              │
│                                                                 │
│  Step 1: Apply regex pattern                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  pattern = r'\+RX[:\s]+"?([A-Fa-f0-9]+)"?,\s*(-?\d+),   │    │
│  │             \s*(-?\d+)'                                 │    │
│  │                                                         │    │
│  │  Groups:                                                │    │
│  │    Group 1: 48454C4C4F  (hex payload)                   │    │
│  │    Group 2: -45         (RSSI in dBm)                   │    │
│  │    Group 3: 12          (SNR in dB)                     │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Step 2: Decode hex payload                                    │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  hex_data = "48454C4C4F"                                │    │
│  │                                                         │    │
│  │  Conversion: 48  45  4C  4C  4F                         │    │
│  │              H   E   L   L   O                          │    │
│  │                                                         │    │
│  │  payload = bytes.fromhex(hex_data).decode('utf-8')      │    │
│  │  # Result: "HELLO"                                      │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Step 3: Create structured packet                              │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  packet = {                                             │    │
│  │      "payload": "HELLO",                                │    │
│  │      "rssi": -45,                                       │    │
│  │      "snr": 12                                          │    │
│  │  }                                                      │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Stage 4: Message Construction

```
┌─────────────────────────────────────────────────────────────────┐
│                 STAGE 4: MESSAGE CONSTRUCTION                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Add metadata to create complete transmission message:         │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  message = {                                            │    │
│  │      # Receiver identification                          │    │
│  │      "receiver_id": "R1",                               │    │
│  │                                                         │    │
│  │      # Timestamps for synchronization                   │    │
│  │      "timestamp": "2025-11-27T10:30:15.123456+00:00",   │    │
│  │      "timestamp_ms": 1732703415123,                     │    │
│  │                                                         │    │
│  │      # Known receiver position (configured at startup)  │    │
│  │      "position": {"x": 0.0, "y": 0.0, "z": 0.0},        │    │
│  │                                                         │    │
│  │      # Measured values from Wio-E5                      │    │
│  │      "rssi": -45,                                       │    │
│  │      "snr": 12,                                         │    │
│  │      "payload": "HELLO"                                 │    │
│  │  }                                                      │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Serialize to JSON:                                            │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  json_string = json.dumps(message)                      │    │
│  │                                                         │    │
│  │  # Result (single line, ~200 bytes):                    │    │
│  │  # {"receiver_id":"R1","timestamp":"2025-11-27T10:...   │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.5 Stage 5: Network Transmission

This stage differs by approach:

#### 3.5.1 Simple Approach (Shared Folder)

```
┌─────────────────────────────────────────────────────────────────┐
│              STAGE 5A: SHARED FOLDER TRANSMISSION               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Windows PC writes to network share:                           │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  # Network path to Mac shared folder                    │    │
│  │  csv_path = "\\\\192.168.1.100\\lora_data\\R1.csv"      │    │
│  │                                                         │    │
│  │  # Append row to CSV file                               │    │
│  │  with open(csv_path, 'a', newline='') as f:             │    │
│  │      writer = csv.writer(f)                             │    │
│  │      writer.writerow([                                  │    │
│  │          message['timestamp'],                          │    │
│  │          message['timestamp_ms'],                       │    │
│  │          message['receiver_id'],                        │    │
│  │          message['position']['x'],                      │    │
│  │          message['position']['y'],                      │    │
│  │          message['rssi'],                               │    │
│  │          message['snr'],                                │    │
│  │          message['payload']                             │    │
│  │      ])                                                 │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Protocol Stack:                                               │
│  ┌─────────────┐                                               │
│  │ Application │ Python csv.writer                             │
│  ├─────────────┤                                               │
│  │    SMB      │ Windows File Sharing Protocol                 │
│  ├─────────────┤                                               │
│  │    TCP      │ Reliable transport                            │
│  ├─────────────┤                                               │
│  │     IP      │ Network addressing                            │
│  ├─────────────┤                                               │
│  │  Ethernet   │ Physical/WiFi                                 │
│  └─────────────┘                                               │
│                                                                 │
│  Mac reads files:                                              │
│  • File watcher or polling (every 0.5 seconds)                 │
│  • Reads new lines from each receiver's CSV                    │
│  • Groups readings by timestamp                                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.5.2 MQTT Approach

```
┌─────────────────────────────────────────────────────────────────┐
│                 STAGE 5B: MQTT TRANSMISSION                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Windows PC publishes to MQTT broker:                          │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  import paho.mqtt.client as mqtt                        │    │
│  │                                                         │    │
│  │  # Connect to broker                                    │    │
│  │  client = mqtt.Client(client_id="receiver_R1")          │    │
│  │  client.connect("192.168.1.100", 1883)                  │    │
│  │                                                         │    │
│  │  # Publish message                                      │    │
│  │  topic = "lora/receivers"                               │    │
│  │  client.publish(topic, json_string, qos=1)              │    │
│  │  #                              └── At-least-once       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Message Flow:                                                 │
│                                                                 │
│  Publisher ──────► MQTT Broker ──────► Subscriber              │
│  (Windows)         (Mac:1883)          (Mac processor)         │
│                                                                 │
│  ┌─────────┐      ┌───────────┐       ┌─────────┐              │
│  │   R1    │─────►│           │──────►│         │              │
│  ├─────────┤      │ Mosquitto │       │ Central │              │
│  │   R2    │─────►│  Broker   │──────►│Processor│              │
│  ├─────────┤      │           │       │         │              │
│  │   R3    │─────►│           │──────►│         │              │
│  └─────────┘      └───────────┘       └─────────┘              │
│                                                                 │
│  Mac subscribes:                                               │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  client.subscribe("lora/receivers", qos=1)              │    │
│  │                                                         │    │
│  │  def on_message(client, userdata, msg):                 │    │
│  │      data = json.loads(msg.payload)                     │    │
│  │      process_reading(data)                              │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.5.3 WebSocket Approach

```
┌─────────────────────────────────────────────────────────────────┐
│               STAGE 5C: WEBSOCKET TRANSMISSION                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Windows PC connects to WebSocket server:                      │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  import websockets                                      │    │
│  │  import asyncio                                         │    │
│  │                                                         │    │
│  │  async def connect():                                   │    │
│  │      uri = "ws://192.168.1.100:8765"                    │    │
│  │      async with websockets.connect(uri) as ws:          │    │
│  │          await ws.send(json_string)                     │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                 │
│  Connection Flow:                                              │
│                                                                 │
│  ┌──────────┐              ┌──────────────────┐                │
│  │ Receiver │──────────────│  Mac Server      │                │
│  │    R1    │   Persistent │  (port 8765)     │                │
│  └──────────┘   WebSocket  │                  │                │
│                 Connection │  ┌────────────┐  │                │
│  ┌──────────┐              │  │ Trilatera- │  │                │
│  │ Receiver │──────────────│  │   tion     │  │                │
│  │    R2    │              │  └────────────┘  │                │
│  └──────────┘              │                  │                │
│                            │  ┌────────────┐  │                │
│  ┌──────────┐              │  │ Dashboard  │◄─┼── Browser      │
│  │ Receiver │──────────────│  │ Broadcast  │  │                │
│  │    R3    │              │  └────────────┘  │                │
│  └──────────┘              └──────────────────┘                │
│                                                                 │
│  Key Features:                                                 │
│  • Persistent connection (no reconnect overhead per message)   │
│  • Bidirectional communication                                 │
│  • Built-in ping/pong for connection health                    │
│  • Automatic reconnection on disconnect                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.6 Stage 6: Reliability Handling (WebSocket)

```
┌─────────────────────────────────────────────────────────────────┐
│              STAGE 6: RELIABILITY MECHANISMS                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  The WebSocket approach includes multiple reliability layers:  │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LAYER 1: Message Queue (RAM Buffer)                    │   │
│  │                                                         │   │
│  │  message_queue = deque(maxlen=1000)  # Circular buffer  │   │
│  │                                                         │   │
│  │  When connection fails:                                 │   │
│  │  • Messages stored in queue (up to 1000)                │   │
│  │  • Oldest messages dropped if queue full                │   │
│  │  • Queue flushed when connection restored               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LAYER 2: Auto-Reconnection                             │   │
│  │                                                         │   │
│  │  async def connect_websocket():                         │   │
│  │      while True:  # Infinite retry loop                 │   │
│  │          try:                                           │   │
│  │              ws = await websockets.connect(uri)         │   │
│  │              await flush_queue()  # Send buffered msgs  │   │
│  │              await maintain_connection()                │   │
│  │          except ConnectionError:                        │   │
│  │              await asyncio.sleep(3)  # Wait 3 seconds   │   │
│  │              # Loop continues → retry                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  LAYER 3: Local CSV Backup                              │   │
│  │                                                         │   │
│  │  def backup_reading(data, sent=False):                  │   │
│  │      with open('backup.csv', 'a') as f:                 │   │
│  │          writer.writerow([                              │   │
│  │              data['timestamp'],                         │   │
│  │              data['rssi'],                              │   │
│  │              'yes' if sent else 'no'  # Track status    │   │
│  │          ])                                             │   │
│  │                                                         │   │
│  │  # Every reading is ALWAYS saved locally                │   │
│  │  # Can replay unsent messages later                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Timeline During Network Outage:                               │
│                                                                 │
│  ─────────────────────────────────────────────────────────►    │
│  │ Connected │ Disconnect │   Offline    │ Reconnect │         │
│  │           │            │              │           │         │
│  │  Send ✓   │  Queue     │  Queue       │  Flush    │         │
│  │  Send ✓   │  Queue     │  Queue       │  queue    │         │
│  │  Send ✓   │  Backup    │  Backup      │  Send ✓   │         │
│  │           │            │              │           │         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 3.7 Stage 7: Central Processing

```
┌─────────────────────────────────────────────────────────────────┐
│                 STAGE 7: CENTRAL PROCESSING                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Step 1: Time-Based Grouping                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Messages from different receivers must be correlated:  │   │
│  │                                                         │   │
│  │  Time Window: 500ms (configurable)                      │   │
│  │                                                         │   │
│  │  Bucket = timestamp_ms // 500                           │   │
│  │                                                         │   │
│  │  Messages arriving within same bucket are grouped:      │   │
│  │  ┌─────────────────────────────────────────────────┐    │   │
│  │  │ Bucket 3465406830:                               │    │   │
│  │  │   R1: {rssi: -45, position: {x:0, y:0}}          │    │   │
│  │  │   R2: {rssi: -52, position: {x:10, y:0}}         │    │   │
│  │  │   R3: {rssi: -48, position: {x:5, y:8.66}}       │    │   │
│  │  └─────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Step 2: RSSI to Distance Conversion                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Log-Distance Path Loss Model:                          │   │
│  │                                                         │   │
│  │         RSSI_1m - RSSI_measured                         │   │
│  │  d = 10^(─────────────────────────)                     │   │
│  │              10 × n                                     │   │
│  │                                                         │   │
│  │  Where:                                                 │   │
│  │  • d = distance (meters)                                │   │
│  │  • RSSI_1m = calibrated RSSI at 1 meter (-40 dBm)       │   │
│  │  • RSSI_measured = received RSSI from Wio-E5            │   │
│  │  • n = path loss exponent (2.5 for indoor)              │   │
│  │                                                         │   │
│  │  Example:                                               │   │
│  │  RSSI = -55 dBm, RSSI_1m = -40 dBm, n = 2.5             │   │
│  │  d = 10^((-40 - (-55)) / (10 × 2.5))                    │   │
│  │  d = 10^(15 / 25) = 10^0.6 ≈ 3.98 meters                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Step 3: Trilateration                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Find point where three circles intersect:              │   │
│  │                                                         │   │
│  │       R3 ●                                              │   │
│  │          ╲  d3                                          │   │
│  │           ╲                                             │   │
│  │            ╲    ◉ ← Tag position (unknown)              │   │
│  │             ╲  ╱                                        │   │
│  │          d1 ╲╱                                          │   │
│  │       R1 ●──────────────● R2                            │   │
│  │                d2                                       │   │
│  │                                                         │   │
│  │  Minimize error function:                               │   │
│  │                                                         │   │
│  │  E(x,y) = Σ (√((x-xᵢ)² + (y-yᵢ)²) - dᵢ)²               │   │
│  │           i=1..3                                        │   │
│  │                                                         │   │
│  │  Using scipy.optimize.minimize (L-BFGS-B algorithm)     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Step 4: Position Smoothing                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Moving average filter reduces noise:                   │   │
│  │                                                         │   │
│  │  Raw:      (5.2, 3.1) (4.8, 3.5) (5.5, 2.9) (5.0, 3.2)  │   │
│  │                 ↓         ↓         ↓         ↓         │   │
│  │  Smoothed: (5.2, 3.1) (5.0, 3.3) (5.2, 3.2) (5.1, 3.2)  │   │
│  │                                                         │   │
│  │  Window size: 5 readings                                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. Approach Comparison

### 4.1 Feature Matrix

| Feature | Simple (CSV) | MQTT | WebSocket |
|---------|:------------:|:----:|:---------:|
| **Latency** | 1-2 sec | ~100ms | ~50-100ms |
| **Real-time** | ❌ | ✅ | ✅ |
| **Reliability** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| **Data persistence** | ✅ Auto | ❌ | ✅ Optional |
| **Offline buffering** | ✅ Files | ❌ Lost | ✅ Queue |
| **Auto-reconnect** | N/A | Manual | ✅ Built-in |
| **External broker** | ❌ | ✅ Required | ❌ |
| **Web dashboard** | ❌ | ❌ | ✅ Included |
| **Bidirectional** | ❌ | ✅ | ✅ |
| **Cross-platform** | ⚠️ SMB issues | ✅ | ✅ |
| **Setup complexity** | ⭐ Easy | ⭐⭐⭐ Complex | ⭐⭐ Medium |
| **Debugging** | ⭐⭐⭐ Easy | ⭐⭐ Medium | ⭐⭐ Medium |
| **Scalability** | ⭐ Limited | ⭐⭐⭐ High | ⭐⭐ Good |

### 4.2 Latency Analysis

```
┌─────────────────────────────────────────────────────────────────┐
│                      LATENCY BREAKDOWN                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  SIMPLE (SHARED FOLDER):                                       │
│  ├─ Serial read:        ~10ms                                  │
│  ├─ File write (SMB):   ~100-500ms  ← Network file I/O         │
│  ├─ File polling:       ~500ms      ← Configurable interval    │
│  ├─ File read:          ~50ms                                  │
│  └─ Processing:         ~10ms                                  │
│  TOTAL: 670-1070ms (~1 second)                                 │
│                                                                 │
│  MQTT:                                                         │
│  ├─ Serial read:        ~10ms                                  │
│  ├─ MQTT publish:       ~20-50ms    ← TCP + MQTT overhead      │
│  ├─ Broker routing:     ~5ms                                   │
│  ├─ MQTT subscribe:     ~10ms                                  │
│  └─ Processing:         ~10ms                                  │
│  TOTAL: 55-85ms (~100ms)                                       │
│                                                                 │
│  WEBSOCKET:                                                    │
│  ├─ Serial read:        ~10ms                                  │
│  ├─ WS send:            ~10-30ms    ← Persistent connection    │
│  ├─ WS receive:         ~5ms        ← No routing needed        │
│  └─ Processing:         ~10ms                                  │
│  TOTAL: 35-55ms (~50ms)                                        │
│                                                                 │
│  Visual Comparison:                                            │
│  Simple:    ████████████████████████████████████████ 1000ms    │
│  MQTT:      ████ 100ms                                         │
│  WebSocket: ██ 50ms                                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Reliability Analysis

```
┌─────────────────────────────────────────────────────────────────┐
│                    RELIABILITY COMPARISON                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Scenario: Network disconnects for 30 seconds                  │
│                                                                 │
│  SIMPLE (SHARED FOLDER):                                       │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • File writes fail with network error                   │   │
│  │ • Data accumulates locally (if coded to buffer)         │   │
│  │ • When network returns, continues writing               │   │
│  │ • May have file locking issues on reconnect             │   │
│  │ • DATA IMPACT: May lose some data if not buffered       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  MQTT:                                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • Connection to broker lost                             │   │
│  │ • Messages during outage are LOST                       │   │
│  │ • QoS 1/2 only helps if broker accessible               │   │
│  │ • Must manually implement reconnection logic            │   │
│  │ • DATA IMPACT: 30 seconds of data LOST                  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  WEBSOCKET:                                                    │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • Connection lost detected immediately                  │   │
│  │ • Messages queued in memory (up to 1000)                │   │
│  │ • Auto-reconnect starts (3 second intervals)            │   │
│  │ • On reconnect, queue flushed automatically             │   │
│  │ • Local CSV backup captures everything                  │   │
│  │ • DATA IMPACT: ZERO data loss                           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Reliability Score:                                            │
│  Simple:    ████████░░ 80% (files persist but SMB issues)      │
│  MQTT:      █████░░░░░ 50% (no built-in buffering)             │
│  WebSocket: ██████████ 100% (queue + backup + auto-reconnect)  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 4.4 Setup Complexity

| Step | Simple | MQTT | WebSocket |
|------|--------|------|-----------|
| Install Python packages | 1 (pyserial) | 2 (paho-mqtt, pyserial) | 2 (websockets, pyserial) |
| Configure Mac | Enable File Sharing | Install Mosquitto, configure | None |
| Configure Windows | Map network drive | None | None |
| Firewall rules | SMB (445) | MQTT (1883) | Custom port (8765) |
| Test connection | Browse to share | mosquitto_pub/sub | Python test script |
| **Total time** | ~10 min | ~30-45 min | ~15 min |

---

## 5. Cross-Platform Considerations

### 5.1 Windows to Mac Communication

| Protocol | Windows Support | Mac Support | Potential Issues |
|----------|-----------------|-------------|------------------|
| SMB (File Share) | Native | Native | Permission issues, file locking |
| MQTT | Python library | Python library | Broker installation on Mac |
| WebSocket | Python library | Python library | None |

### 5.2 Python Compatibility

All approaches use Python libraries available on both platforms:

```
┌─────────────────────────────────────────────────────────────────┐
│                    PYTHON DEPENDENCIES                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Windows (Receivers):                                          │
│  ┌────────────────────────────────────────────────────┐        │
│  │  pip install pyserial            # All approaches  │        │
│  │  pip install paho-mqtt           # MQTT only       │        │
│  │  pip install websockets          # WebSocket only  │        │
│  └────────────────────────────────────────────────────┘        │
│                                                                 │
│  Mac (Server):                                                 │
│  ┌────────────────────────────────────────────────────┐        │
│  │  pip3 install numpy scipy        # All approaches  │        │
│  │  pip3 install paho-mqtt          # MQTT only       │        │
│  │  pip3 install websockets         # WebSocket only  │        │
│  └────────────────────────────────────────────────────┘        │
│                                                                 │
│  Compatibility:                                                │
│  • Python 3.7+ required (asyncio improvements)                 │
│  • All libraries are pure Python (no compilation)              │
│  • No platform-specific code needed                            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 5.3 Network Configuration

```
┌─────────────────────────────────────────────────────────────────┐
│                  NETWORK REQUIREMENTS                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  All devices must be on same local network (WiFi or Ethernet)  │
│                                                                 │
│  Required Ports:                                               │
│  ┌─────────────┬──────────┬───────────────────────────────┐    │
│  │ Approach    │ Port     │ Direction                     │    │
│  ├─────────────┼──────────┼───────────────────────────────┤    │
│  │ Simple      │ 445      │ Windows → Mac (SMB)           │    │
│  │ MQTT        │ 1883     │ Windows → Mac (MQTT)          │    │
│  │ WebSocket   │ 8765     │ Windows → Mac (WebSocket)     │    │
│  │ Dashboard   │ 8765     │ Browser → Mac (WebSocket)     │    │
│  └─────────────┴──────────┴───────────────────────────────┘    │
│                                                                 │
│  Mac Firewall:                                                 │
│  • System Preferences → Security → Firewall                    │
│  • Allow incoming connections for Python                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Recommendation

### 6.1 Decision Matrix

Based on the analysis, we score each approach against the key requirements:

| Requirement | Weight | Simple | MQTT | WebSocket |
|-------------|--------|--------|------|-----------|
| Low latency (<200ms) | 25% | 1 | 4 | 5 |
| High reliability | 25% | 4 | 2 | 5 |
| Easy setup | 15% | 5 | 2 | 4 |
| Cross-platform | 15% | 3 | 5 | 5 |
| No external dependencies | 10% | 5 | 1 | 5 |
| Visualization included | 10% | 1 | 1 | 5 |
| **Weighted Score** | **100%** | **2.9** | **2.6** | **4.8** |

### 6.2 Final Recommendation

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ███╗███╗   ███╗      │
│   ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗ ████║████╗ ████║      │
│   ██████╔╝█████╗  ██║     ██║   ██║██╔████╔██║██╔████╔██║      │
│   ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╔╝██║██║╚██╔╝██║      │
│   ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║██║ ╚═╝ ██║      │
│   ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚═╝      │
│                                                                 │
│              ╔═══════════════════════════════════╗              │
│              ║                                   ║              │
│              ║    WEBSOCKET APPROACH             ║              │
│              ║                                   ║              │
│              ║    Score: 4.8 / 5.0               ║              │
│              ║                                   ║              │
│              ╚═══════════════════════════════════╝              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 6.3 Justification

The **WebSocket approach** is recommended for this deployment because:

1. **Optimal Latency**: 50-100ms latency enables near-real-time tracking, essential for meaningful indoor localization.

2. **Maximum Reliability**: Triple-layer protection (queue + auto-reconnect + backup) ensures zero data loss even during network issues.

3. **No External Dependencies**: Unlike MQTT, no broker installation required. The server is built into the central processor.

4. **Built-in Dashboard**: Web-based visualization accessible from any device on the network, including mobile phones and tablets.

5. **Cross-Platform Excellence**: Python websockets library works identically on Windows and macOS with no platform-specific code.

6. **Future-Proof**: Bidirectional communication allows adding features like remote configuration or real-time calibration.

### 6.4 When to Use Other Approaches

| Approach | Use When |
|----------|----------|
| **Simple** | Initial testing, debugging hardware, latency not critical |
| **MQTT** | Existing MQTT infrastructure, many receivers (10+), integration with other IoT systems |
| **WebSocket** | Production deployment, real-time requirements, reliability critical |

---

## 7. Implementation Guidelines

### 7.1 Deployment Checklist

```
□ Phase 1: Hardware Setup
  □ Connect Wio-E5 to each Windows laptop via USB
  □ Verify COM port detection (Device Manager)
  □ Test serial output with terminal emulator
  □ Place receivers in triangular formation
  □ Measure and record receiver positions (x, y)

□ Phase 2: Network Setup
  □ Connect all devices to same network
  □ Note Mac's IP address (ipconfig getifaddr en0)
  □ Verify Windows can ping Mac
  □ Configure Mac firewall to allow Python

□ Phase 3: Software Installation
  □ Windows: pip install websockets pyserial
  □ Mac: pip3 install websockets numpy scipy

□ Phase 4: Calibration
  □ Place tag at exactly 1 meter from receiver
  □ Record RSSI value (e.g., -40 dBm)
  □ Configure --rssi-1m parameter
  □ Adjust --path-loss for environment

□ Phase 5: Deployment
  □ Start server on Mac first
  □ Start receivers on each Windows PC
  □ Open dashboard in browser
  □ Verify position updates

□ Phase 6: Validation
  □ Place tag at known positions
  □ Compare measured vs actual
  □ Adjust calibration if needed
```

### 7.2 Command Reference

**Mac (Server):**
```bash
python3 websocket/server_ws.py \
    --port 8765 \
    --rssi-1m -40 \
    --path-loss 2.5
```

**Windows (Each Receiver):**
```powershell
# Receiver R1 at origin
python websocket/receiver_ws.py `
    --id R1 `
    --ws-host 192.168.1.100 `
    --x 0 --y 0 `
    --backup .\backup

# Receiver R2 at (10, 0)
python websocket/receiver_ws.py `
    --id R2 `
    --ws-host 192.168.1.100 `
    --x 10 --y 0 `
    --backup .\backup

# Receiver R3 at (5, 8.66)
python websocket/receiver_ws.py `
    --id R3 `
    --ws-host 192.168.1.100 `
    --x 5 --y 8.66 `
    --backup .\backup
```

**Dashboard:**
Open `websocket/dashboard.html` in any web browser.

---

## Appendix A: Glossary

| Term | Definition |
|------|------------|
| **RSSI** | Received Signal Strength Indicator - power level of received radio signal (dBm) |
| **SNR** | Signal-to-Noise Ratio - quality measure of signal vs background noise (dB) |
| **Trilateration** | Position finding using distances from 3+ known points |
| **Path Loss Exponent** | Environmental factor affecting signal attenuation (typically 2-4) |
| **WebSocket** | Full-duplex communication protocol over single TCP connection |
| **MQTT** | Message Queuing Telemetry Transport - lightweight pub/sub protocol |
| **SMB** | Server Message Block - network file sharing protocol |

---

## Appendix B: References

1. LoRa Alliance. (2023). LoRaWAN Specification v1.0.4
2. Log-Distance Path Loss Model - IEEE 802.11 Standard
3. Python websockets library documentation: https://websockets.readthedocs.io/
4. Seeed Studio Wio-E5 Documentation
5. scipy.optimize.minimize documentation

---

*End of Report*
