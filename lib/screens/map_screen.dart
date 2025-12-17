import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? deviceName;
  final double? accuracy;
  final bool showUserLocation;
  final double? userLatitude;
  final double? userLongitude;

  const MapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.deviceName,
    this.accuracy,
    this.showUserLocation = false,
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  double _currentZoom = 16.0;

  @override
  Widget build(BuildContext context) {
    final deviceLocation = LatLng(widget.latitude, widget.longitude);
    
    final markers = <Marker>[
      Marker(
        point: deviceLocation,
        width: 80,
        height: 80,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade800,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.deviceName ?? 'Device',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.location_on,
              color: Colors.red,
              size: 40,
            ),
          ],
        ),
      ),
    ];

    if (widget.showUserLocation && 
        widget.userLatitude != null && 
        widget.userLongitude != null) {
      markers.add(
        Marker(
          point: LatLng(widget.userLatitude!, widget.userLongitude!),
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: const Icon(
              Icons.person_pin,
              color: Colors.blue,
              size: 24,
            ),
          ),
        ),
      );
    }

    final circles = <CircleMarker>[];
    if (widget.accuracy != null && widget.accuracy! > 0) {
      circles.add(
        CircleMarker(
          point: deviceLocation,
          radius: widget.accuracy!,
          useRadiusInMeter: true,
          color: Colors.blue.withValues(alpha: 0.1),
          borderColor: Colors.blue.withValues(alpha: 0.5),
          borderStrokeWidth: 2,
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: deviceLocation,
            initialZoom: _currentZoom,
            minZoom: 3,
            maxZoom: 18,
            onPositionChanged: (position, hasGesture) {
              if (hasGesture && position.zoom != null) {
                setState(() => _currentZoom = position.zoom!);
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.loratrack',
              maxZoom: 19,
            ),
            if (circles.isNotEmpty)
              CircleLayer(circles: circles),
            MarkerLayer(markers: markers),
          ],
        ),
        Positioned(
          right: 16,
          bottom: 100,
          child: Column(
            children: [
              _buildMapButton(
                icon: Icons.add,
                onPressed: () {
                  final newZoom = (_currentZoom + 1).clamp(3.0, 18.0);
                  _mapController.move(
                    _mapController.camera.center,
                    newZoom,
                  );
                  setState(() => _currentZoom = newZoom);
                },
              ),
              const SizedBox(height: 8),
              _buildMapButton(
                icon: Icons.remove,
                onPressed: () {
                  final newZoom = (_currentZoom - 1).clamp(3.0, 18.0);
                  _mapController.move(
                    _mapController.camera.center,
                    newZoom,
                  );
                  setState(() => _currentZoom = newZoom);
                },
              ),
              const SizedBox(height: 8),
              _buildMapButton(
                icon: Icons.my_location,
                onPressed: () {
                  _mapController.move(deviceLocation, 16);
                  setState(() => _currentZoom = 16);
                },
              ),
            ],
          ),
        ),
        if (widget.accuracy != null)
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.gps_fixed, size: 16, color: Colors.blue.shade800),
                  const SizedBox(width: 8),
                  Text(
                    'Accuracy: ${widget.accuracy!.toStringAsFixed(1)}m',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue.shade800),
        ),
      ),
    );
  }
}

class FullScreenMapPage extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? deviceName;
  final double? accuracy;

  const FullScreenMapPage({
    super.key,
    required this.latitude,
    required this.longitude,
    this.deviceName,
    this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(deviceName ?? 'Device Location'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
      ),
      body: MapScreen(
        latitude: latitude,
        longitude: longitude,
        deviceName: deviceName,
        accuracy: accuracy,
      ),
    );
  }
}
