import 'package:geolocator/geolocator.dart';

class LocationReading {
  final Position? position;
  final String? error;

  const LocationReading({this.position, this.error});

  bool get hasFix => position != null;
}

class LocationService {
  Future<LocationReading> getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationReading(error: 'Location services are disabled');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationReading(error: 'Location permission denied');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationReading(
          error: 'Location permission permanently denied',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LocationReading(position: position);
    } catch (e) {
      return LocationReading(error: e.toString());
    }
  }
}
