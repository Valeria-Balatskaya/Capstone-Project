import 'package:geolocator/geolocator.dart';

class LocationResult {
  final Position? position;
  final String? error;
  final bool permissionDenied;

  const LocationResult({
    this.position,
    this.error,
    this.permissionDenied = false,
  });

  bool get hasPosition => position != null;
  bool get hasError => error != null;
}

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _permissionGranted = false;

  bool get hasPermission => _permissionGranted;

  Future<LocationResult> checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          error: 'Location services are disabled. Please enable GPS.',
          permissionDenied: false,
        );
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _permissionGranted = false;
        return const LocationResult(
          error: 'Location permission denied.',
          permissionDenied: true,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        _permissionGranted = false;
        return const LocationResult(
          error: 'Location permission permanently denied. Please enable in settings.',
          permissionDenied: true,
        );
      }

      _permissionGranted = true;
      return const LocationResult();
    } catch (e) {
      return LocationResult(error: 'Failed to check permission: $e');
    }
  }

  Future<LocationResult> getCurrentLocation() async {
    try {
      final permissionResult = await checkAndRequestPermission();
      if (permissionResult.hasError) {
        return permissionResult;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      return LocationResult(position: position);
    } catch (e) {
      return LocationResult(error: 'Failed to get location: $e');
    }
  }

  Future<Position?> getLastKnownLocation() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      return null;
    }
  }

  double calculateDistance(
    double startLat,
    double startLon,
    double endLat,
    double endLon,
  ) {
    return Geolocator.distanceBetween(startLat, startLon, endLat, endLon);
  }

  Stream<Position> getPositionStream({
    int intervalMs = 5000,
    int distanceFilter = 10,
  }) {
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
