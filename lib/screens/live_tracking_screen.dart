import 'package:flutter/material.dart';
import 'app_drawer.dart';
import '../services/device_service.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'map_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final DeviceService _deviceService = DeviceService();
  final LocationService _locationService = LocationService();

  List<Map<String, dynamic>> devices = [];
  Map<String, dynamic>? selectedDevice;
  Position? _gpsPosition;
  String? _gpsError;
  bool _isFetchingGps = false;
  double? _lat;
  double? _lon;
  String? _error;

  double xPosition = 12.5;
  double yPosition = 8.3;
  int gatewayCount = 3;
  double accuracy = 5.2;
  bool isTracking = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
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

  void _refreshPosition() {
    setState(() {
      xPosition += (0.5 - (xPosition % 1));
      yPosition += (0.3 - (yPosition % 1));
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Position refreshed'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _readPhoneLocation() async {
    setState(() {
      _isFetchingGps = true;
      _gpsError = null;
    });
    final reading = await _locationService.getCurrentLocation();
    if (!mounted) {
      return;
    }
    setState(() {
      _isFetchingGps = false;
      if (reading.hasFix) {
        _gpsPosition = reading.position;
        _gpsError = null;
      } else {
        _gpsError = reading.error ?? 'Unable to read GPS';
      }
    });
    if (_gpsError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_gpsError!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone GPS updated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    }
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
      ),
      drawer: const AppDrawer(currentRoute: 'position'),
      body: Stack(
        children: [
          Column(
            children: [
              /*Expanded(
                flex: 4,
                child: Container(
                  color: Colors.grey.shade200,
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map,
                              size: 80,
                              color: Colors.grey.shade400,
                            ),
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
                              'Google Maps - Week 7',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isTracking ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.shade400,
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isTracking ? 'LIVE' : 'OFFLINE',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),*/
              Expanded(
                flex: 4,
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
                          'Google Maps - Week 7',
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.blue.shade800,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Current Position',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'X',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${xPosition.toStringAsFixed(2)} m',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Y',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                '${yPosition.toStringAsFixed(2)} m',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

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

          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton(
              onPressed: _refreshPosition,
              backgroundColor: Colors.blue.shade800,
              child: const Icon(Icons.my_location),
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
        ? _gpsPosition!.timestamp.toLocal().toString()
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Phone GPS Fix',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    Text(
                      _gpsError ?? 'Compare handset GPS with LoRa position',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () async {
                    final reading = await LocationService().getCurrentLocation();

                    if (!reading.hasFix) {
                      setState(() {
                        _error = reading.error ?? "Could not get location";
                      });
                      return;
                    }

                    final pos = reading.position!;

                    setState(() {
                      _lat = pos.latitude;
                      _lon = pos.longitude;
                      _error = null;
                    });

                    /*Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MapScreen(
                          latitude: pos.latitude,
                          longitude: pos.longitude,
                        ),
                      ),
                    );*/
                    setState(() {
                      _lat = pos.latitude;
                      _lon = pos.longitude;
                      _error = null;
                    });

                  },
                  child: const Text("Locate"),
                )


                ,
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
                Expanded(child: _buildGpsStat('Timestamp', timestamp)),
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
