# LoraTrack

**Version 1.1.0**

A Flutter mobile application for real-time indoor position tracking using LoRaWAN technology without GPS dependency.

## Overview

LoraTrack is a mobile application for Capstone Module project that demonstrates GPS-free indoor positioning using LoRaWAN protocol. The app displays real-time device positions calculated from RSSI-based trilateration with outdoor gateways tracking indoor tags.

## Features

- **Live Position Tracking** - Real-time visualization of device location
- **Device Management** - Monitor multiple LoRaWAN tracking tags
- **Settings Configuration** - Configure ChirpStack server connection
- **Hamburger Menu Navigation** - Easy access to all features
- **Position History** - Track device movement over time
- **Status Indicators** - Live/offline status, battery levels, accuracy metrics

## Tech Stack

- **Framework:** Flutter 3.120.0 / Dart
- **LoRaWAN Protocol:** ChirpStack network server integration
- **Positioning:** RSSI-based trilateration
- **Communication:** MQTT for real-time updates
- **Storage:** SQLite, InfluxDB

## Project Structure
lib/
├── screens/
│ ├── live_tracking_screen.dart # Main position map
│ ├── device_list_screen.dart # Device management
│ ├── settings_screen.dart # App configuration
│ └── about_screen.dart # Project information
├── main.dart # App entry point

## Getting Started

### Prerequisites

- Flutter SDK (3.0+)
- Dart SDK
- Android Studio / VS Code
- ChirpStack server (for production)

### Installation

1. Clone the repository:

git clone https://github.com/Valeria-Balatskaya/Capstone-Project.git

2. Install dependencies:

flutter pub get

3. Run the app:

flutter run

## Usage

1. **Launch App** - Opens directly to live position tracking
2. **Tap Hamburger Menu** - Access devices, settings, and about
3. **View Devices** - Monitor all tracked LoRaWAN tags
4. **Configure Settings** - Set ChirpStack server details (Week 4)
5. **Refresh Position** - Tap floating button to update location

## Project Context 

**Capstone Project:** Position Measurement Using LoRaWAN

**Requirements:**
- Localize moving tags inside buildings
- Use outdoor gateways only (no GPS)
- Real-time or near-real-time tracking
- Measure accuracy, coverage, and power consumption

## Team members

1. Vladyslav Dubenchuk
2. Valeriia Balatska
3. Daniyar Zhumataev
4. Kuzma Martysiuk

## Versioning 

# Version 1.1.0

- Hamburger menu navigation
- Consistent UI 
- Requirements from Week3 completed

# Version 1.0.0

- Hello UI 
- Requirements for Week2 completed