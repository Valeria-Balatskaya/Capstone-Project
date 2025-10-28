# LoraTrack

**Version 1.2.0**

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
│ ├── live_tracking_screen.dart # Main position map with device selector
│ ├── device_list_screen.dart # Device management (add/edit/delete)
│ ├── device_detail_screen.dart # Individual device details view
│ ├── settings_screen.dart # App configuration with forms
│ └── about_screen.dart # Project information
├── services/
│ ├── device_service.dart # Device persistence service
│ └── settings_service.dart # Settings persistence service
├── models/
│ └── app_settings.dart # Settings data model
└── main.dart # App entry point

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


### Basic Navigation
1. **Launch App** - Opens directly to live position tracking
2. **Select Device** - Tap device name in AppBar to switch tracked device
3. **Tap Hamburger Menu** - Access devices, settings, and about screens
4. **Refresh Position** - Tap floating button to update location

### Device Management
1. **Add Device** - Tap "+" in Devices screen, enter DevEUI, name, and description
2. **View Details** - Tap device card, select "View Details" for full information
3. **Edit Device** - From device options menu, modify device information
4. **Delete Device** - Long-press device or use options menu (with undo support)

### Settings Configuration
1. **ChirpStack Server** - Enter server URL (e.g., http://192.168.1.100:8080)
2. **API Token** - Configure authentication credentials
3. **MQTT Broker** - Set broker address for real-time updates
4. **Update Interval** - Adjust position refresh rate (1-30 seconds)
5. **Notifications** - Enable/disable position update alerts

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

### Version 1.2.0 (Week 4 - October 2025)
- Forms and user input validation
- Persistent storage for devices and settings
- Device management (add, edit, delete with undo)
- Device selector on main tracking screen
- Device detail view screen
- Settings form with ChirpStack server configuration
- Update interval and notification preferences
- Dynamic device count display
- Form validation for server URLs and API tokens

### Version 1.1.0 (Week 3 - October 2025)

- Hamburger menu navigation
- Consistent UI 
- Requirements from Week3 completed

### Version 1.0.0 (Week 2 - October 2025)

- Hello UI 
- Requirements for Week2 completed