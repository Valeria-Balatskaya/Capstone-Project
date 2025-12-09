import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../services/device_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'package:geolocator/geolocator.dart';
import 'map_screen.dart';

class GPSState {
  static double? savedLat;
  static double? savedLon;
  static Position? savedPosition;
}

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final DeviceService _deviceService = DeviceService();
  final LocationService _locationService = LocationService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  List<Map<String, dynamic>> devices = [];
  Map<String, dynamic>? selectedDevice;
  Position? _gpsPosition;
  String? _gpsError;
  bool _isFetchingGps = false;
  double? _lat;
  double? _lon;
  bool _isSynced = false;

  int gatewayCount = 3;
  double accuracy = 5.2;
  bool isTracking = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _checkSyncStatus();
    _restoreGPSLocation();
  }

  void _restoreGPSLocation() {
    if (GPSState.savedLat != null && GPSState.savedLon != null) {
      setState(() {
        _lat = GPSState.savedLat;
        _lon = GPSState.savedLon;
        _gpsPosition = GPSState.savedPosition;
      });
    }
  }

  Future<void> _checkSyncStatus() async {
    if (_authService.isLoggedIn) {
      final status = await _firestoreService.getSyncStatus();
      if (mounted) {
        setState(() => _isSynced = status['synced'] ?? false);
      }
    }
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    final loadedDevices = await _deviceService.loadDevices();
    setState(() {
      devices = loadedDevices;
      if (devices.isNotEmpty) {
        selectedDevice = devices.firstWhere(
              (device) => device['status'] == 'online',
          orElse: () => devices.first,
        );
        _updateTrackingData();
      }
      _isLoading = false;
    });
    _checkSyncStatus();
  }

  void _updateTrackingData() {
    if (selectedDevice != null) {
      setState(() {
        isTracking = selectedDevice!['status'] == 'online';
        accuracy = selectedDevice!['accuracy']?.toDouble() ?? 0.0;
        gatewayCount = devices.where((d) => d['status'] == 'online').length;
      });
    }
  }

  void _showDeviceSelector() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Device to Track',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  final isSelected = selectedDevice?['id'] == device['id'];
                  final isOnline = device['status'] == 'online';

                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? Colors.green.shade50
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.sensors,
                        color: isOnline ? Colors.green : Colors.grey,
                      ),
                    ),
                    title: Text(
                      device['name'],
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      device['status'].toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        color: isOnline ? Colors.green : Colors.grey,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: Colors.blue.shade800)
                        : null,
                    onTap: () {
                      setState(() {
                        selectedDevice = device;
                        _updateTrackingData();
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Now tracking ${device['name']}'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncIndicator() {
    if (!_authService.isLoggedIn) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isSynced ? Colors.green.shade100 : Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSynced ? Icons.cloud_done : Icons.cloud_upload,
              size: 16,
              color: _isSynced ? Colors.green.shade700 : Colors.orange.shade700,
            ),
            const SizedBox(width: 4),
            Text(
              _isSynced ? 'Synced' : 'Syncing',
              style: TextStyle(
                fontSize: 11,
                color: _isSynced ? Colors.green.shade700 : Colors.orange.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Live Tracking'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (devices.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Live Tracking'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
          actions: [_buildSyncIndicator()],
        ),
        drawer: const AppDrawer(currentRoute: 'position'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.devices_other, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 20),
              Text(
                'No devices available',
                style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 10),
              Text(
                'Add devices to start tracking',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showDeviceSelector,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selectedDevice?['name'] ?? 'No Device'),
              const SizedBox(width: 5),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [_buildSyncIndicator()],
      ),
      drawer: const AppDrawer(currentRoute: 'position'),
      body: Column(
        children: [
          Expanded(
            child: _lat != null && _lon != null
                ? MapScreen(latitude: _lat!, longitude: _lon!)
                : Container(
              color: Colors.grey.shade200,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.map, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 20),
                    Text(
                      'Live Position Map',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Tap "Locate" below to show your position',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickInfo(
                      icon: Icons.router,
                      label: 'Devices',
                      value: '${devices.length}',
                      color: Colors.green,
                    ),
                    _buildDivider(),
                    _buildQuickInfo(
                      icon: Icons.gps_fixed,
                      label: 'Accuracy',
                      value: '${accuracy.toStringAsFixed(1)}m',
                      color: Colors.orange,
                    ),
                    _buildDivider(),
                    _buildQuickInfo(
                      icon: Icons.update,
                      label: 'Updated',
                      value: 'Just now',
                      color: Colors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildGpsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 40, width: 1, color: Colors.grey.shade300);
  }

  Widget _buildGpsCard() {
    final latitude = _lat?.toStringAsFixed(6) ?? '--';
    final longitude = _lon?.toStringAsFixed(6) ?? '--';
    final accuracyText = _gpsPosition?.accuracy.toStringAsFixed(1) ?? '--';
    final timestamp = _gpsPosition != null
        ? '${_gpsPosition!.timestamp.toLocal().hour.toString().padLeft(2, '0')}:${_gpsPosition!.timestamp.toLocal().minute.toString().padLeft(2, '0')}:${_gpsPosition!.timestamp.toLocal().second.toString().padLeft(2, '0')}'
        : '--';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone GPS Location',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      Text(
                        _gpsError ?? 'Get your phone\'s GPS coordinates',
                        style: TextStyle(
                          fontSize: 12,
                          color: _gpsError != null ? Colors.red : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _isFetchingGps
                      ? null
                      : () async {
                    setState(() => _isFetchingGps = true);

                    final reading = await _locationService.getCurrentLocation();

                    if (!mounted) return;

                    if (!reading.hasFix) {
                      setState(() {
                        _gpsError = reading.error;
                        _isFetchingGps = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(reading.error ?? 'Could not get location'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    final pos = reading.position!;

                    setState(() {
                      _lat = pos.latitude;
                      _lon = pos.longitude;
                      _gpsPosition = pos;
                      _gpsError = null;
                      _isFetchingGps = false;
                    });

                    GPSState.savedLat = pos.latitude;
                    GPSState.savedLon = pos.longitude;
                    GPSState.savedPosition = pos;

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('📍 Location found!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: _isFetchingGps
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text("Locate"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade800,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildGpsStat('Latitude', latitude)),
                Expanded(child: _buildGpsStat('Longitude', longitude)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildGpsStat('Accuracy', '$accuracyText m')),
                Expanded(child: _buildGpsStat('Time', timestamp)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}