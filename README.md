# LoraTrack v2.0.0

**Grade 5 Mobile Systems Course - Indoor Position Tracking Using LoRaWAN**

A Flutter mobile application demonstrating GPS-free indoor positioning using LoRaWAN technology with AI-powered analytics.

## Features

### Grade 3 Requirements ✅
- **CRUD Operations**: Create, view, edit, and delete device entries
- **Local Storage**: SharedPreferences for offline data persistence
- **Navigation**: Drawer navigation with consistent UI
- **Stable Functionality**: No crashes during basic operations

### Grade 4 Requirements ✅
- **Firebase Authentication**: Email/password registration and login
- **Cloud Synchronization**: Real-time Firebase sync
- **Search & Filter**: Device list with search, status filters, and sorting
- **Notifications**: Smart alerts for battery, signal, and device status

### Grade 5 Requirements ✅
- **AI/ML Integration**: 
  - Z-score anomaly detection
  - Linear regression trend analysis
  - Pattern recognition algorithms
  - Performance scoring with weighted factors
- **Sensor Integration**:
  - GPS location service with permissions
  - Step counter with activity classification
- **External API**:
  - OpenWeatherMap integration
  - Weather-based tracking advice
- **Analytics Dashboard**:
  - Interactive charts with fl_chart
  - Device statistics and history visualization

## Project Structure

```
lib/
├── main.dart                    # App entry point with routes
├── models/
│   ├── device.dart              # Device data model
│   ├── device_history.dart      # Historical tracking data
│   ├── app_settings.dart        # Settings model
│   └── ai_models.dart           # AI analysis models
├── services/
│   ├── auth_service.dart        # Firebase authentication
│   ├── device_service.dart      # Device CRUD + Firebase
│   ├── simulation_service.dart  # Realistic data generation
│   ├── ai_service.dart          # ML algorithms
│   ├── notification_service.dart# Push notifications
│   ├── location_service.dart    # GPS integration
│   ├── weather_service.dart     # OpenWeatherMap API
│   ├── step_counter_service.dart# Pedometer integration
│   └── settings_service.dart    # App settings persistence
├── screens/
│   ├── login_screen.dart        # Authentication
│   ├── register_screen.dart     # User registration
│   ├── live_tracking_screen.dart# Main dashboard
│   ├── device_list_screen.dart  # Device management
│   ├── device_detail_screen.dart# Device details & history
│   ├── analytics_screen.dart    # Charts & statistics
│   ├── ai_assistant_screen.dart # AI insights
│   ├── profile_screen.dart      # User profile
│   ├── settings_screen.dart     # App configuration
│   ├── about_screen.dart        # App information
│   └── map_screen.dart          # Map visualization
└── widgets/
    └── app_drawer.dart          # Navigation drawer
```

## Firebase Setup

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create new project named "LoraTrack"
3. Enable Authentication (Email/Password)
4. Enable Cloud Firebase

### 2. Android Configuration
1. In Firebase Console → Project Settings → Add Android App
2. Package name: `com.example.lorawan_mobile_app`
3. Download `google-services.json`
4. Place in `android/app/` folder

### 3. Firebase Rules
```javascript
rules_version = '2';
service cloud.Firebase {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /devices/{deviceId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        
        match /history/{historyId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
  }
}
```

## Installation

### Prerequisites
- Flutter SDK 3.0+
- Android Studio
- Firebase account

### Steps
1. Clone the repository
2. Run `flutter pub get`
3. Configure Firebase (see above)
4. Run `flutter run`

## How It Works

### Device Creation Flow
1. User creates device → DeviceService generates unique ID
2. SimulationService creates realistic initial values
3. Device saved to Firebase with user isolation
4. Historical data generated for AI analysis

### AI Analysis Flow
1. AI Service fetches device history from Firebase
2. Runs statistical algorithms:
   - **Anomaly Detection**: Z-score analysis (>2 std dev = anomaly)
   - **Trend Analysis**: Linear regression on battery/signal
   - **Pattern Recognition**: Hourly activity, movement distance
3. Generates context-aware suggestions with confidence scores

### Data Consistency
- SimulationService maintains device state in memory
- Same device shows identical values across all screens
- No random regeneration on screen changes

## Testing Guide

1. **Register Account**: Create new user, verify welcome notification
2. **Add Device**: Tap + button, enter device name
3. **Check Consistency**: Same battery/signal on all screens
4. **Test Search**: Type in search box on device list
5. **Test Filters**: Tap filter icon, select status/sort
6. **View AI Insights**: Navigate to AI Assistant screen
7. **Test Location**: Tap "Locate" button on main screen
8. **Test Notifications**: Wait for low battery alert

## Team

- Vladyslav Dubenchuk
- Valeriia Balatska
- Daniyar Zhumataev
- Kuzma Martysiuk

## Version History

### v2.0.0 (December 2025)
- Complete Grade 5 implementation
- Real ML algorithms (not if/else rules)
- Automatic Firebase sync
- Android 13+ permission handling
- Step counter integration
- Weather API integration

### v1.6.0 (November 2025)
- OpenStreetMap integration

### v1.5.0 (November 2025)
- GPS sensor integration
- Phone vs LoRa comparison

## License

© 2025 LoraTrack Team - Mobile Systems Course Capstone Project
