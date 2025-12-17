import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../widgets/app_drawer.dart';
import 'map_screen.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final _deviceService = DeviceService();
  final _locationService = LocationService();
  final _weatherService = WeatherService();

  List<Device> _devices = [];
  Device? _selectedDevice;
  Position? _phonePosition;
  WeatherData? _weather;
  bool _isLoadingLocation = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadWeather();
    setState(() => _isLoading = false);
  }

  Future<void> _loadWeather() async {
    final weather = await _weatherService.getWeatherByCoordinates(51.7592, 19.4560);
    if (mounted) {
      setState(() => _weather = weather);
    }
  }

  void _selectDevice(Device device) {
    setState(() => _selectedDevice = device);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Now tracking ${device.name}'),
        duration: const Duration(seconds: 1),
      ),
    );
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
              child: _devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.devices_other,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'No devices yet',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first device from the Devices screen',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _devices.length,
                      itemBuilder: (context, index) {
                        final device = _devices[index];
                        final isSelected = _selectedDevice?.id == device.id;

                        return ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: device.isOnline
                                  ? Colors.green.shade50
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.sensors,
                              color:
                                  device.isOnline ? Colors.green : Colors.grey,
                            ),
                          ),
                          title: Text(
                            device.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Row(
                            children: [
                              Icon(
                                Icons.battery_std,
                                size: 14,
                                color: device.battery > 20
                                    ? Colors.green
                                    : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text('${device.battery}%'),
                              const SizedBox(width: 12),
                              Icon(Icons.signal_cellular_alt,
                                  size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text('${device.signalStrength}%'),
                            ],
                          ),
                          trailing: isSelected
                              ? Icon(Icons.check_circle,
                                  color: Colors.blue.shade800)
                              : null,
                          onTap: () => _selectDevice(device),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getPhoneLocation() async {
    setState(() => _isLoadingLocation = true);

    final result = await _locationService.getCurrentLocation();

    if (!mounted) return;

    if (result.hasPosition) {
      setState(() {
        _phonePosition = result.position;
        _isLoadingLocation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone location found!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );
    } else {
      setState(() => _isLoadingLocation = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Could not get location'),
          backgroundColor: Colors.red,
          action: result.permissionDenied
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => _locationService.openAppSettings(),
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: _showDeviceSelector,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_selectedDevice?.name ?? 'Select Device'),
              const SizedBox(width: 5),
              const Icon(Icons.arrow_drop_down, size: 20),
            ],
          ),
        ),
        centerTitle: true,
      ),
      drawer: const AppDrawer(currentRoute: 'tracking'),
      body: StreamBuilder<List<Device>>(
        stream: _deviceService.watchDevices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          _devices = snapshot.data ?? [];

          if (_selectedDevice != null) {
            final updatedDevice = _devices.where((d) => d.id == _selectedDevice!.id).firstOrNull;
            if (updatedDevice != null) {
              _selectedDevice = updatedDevice;
            } else if (_devices.isNotEmpty) {
              _selectedDevice = _devices.first;
            }
          } else if (_devices.isNotEmpty && _selectedDevice == null) {
            _selectedDevice = _devices.first;
          }

          return Column(
            children: [
              Expanded(
                child: _buildMapOrPlaceholder(),
              ),
              _buildBottomPanel(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMapOrPlaceholder() {
    if (_selectedDevice != null) {
      return MapScreen(
        latitude: _selectedDevice!.latitude,
        longitude: _selectedDevice!.longitude,
        deviceName: _selectedDevice!.name,
        accuracy: _selectedDevice!.accuracy,
      );
    }

    return Container(
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
              _devices.isEmpty
                  ? 'Add a device to see its location'
                  : 'Select a device to track',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            if (_devices.isNotEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _showDeviceSelector,
                icon: const Icon(Icons.devices),
                label: const Text('Select Device'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
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
          if (_weather != null) _buildWeatherBar(),
          if (_weather != null) const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuickInfo(
                icon: Icons.devices,
                label: 'Devices',
                value: '${_devices.length}',
                color: Colors.blue,
              ),
              _buildDivider(),
              _buildQuickInfo(
                icon: Icons.gps_fixed,
                label: 'Accuracy',
                value: _selectedDevice != null
                    ? '${_selectedDevice!.accuracy.toStringAsFixed(1)}m'
                    : '--',
                color: Colors.orange,
              ),
              _buildDivider(),
              _buildQuickInfo(
                icon: Icons.signal_cellular_alt,
                label: 'Signal',
                value: _selectedDevice != null
                    ? '${_selectedDevice!.signalStrength}%'
                    : '--',
                color: Colors.green,
              ),
              _buildDivider(),
              _buildQuickInfo(
                icon: Icons.battery_std,
                label: 'Battery',
                value: _selectedDevice != null
                    ? '${_selectedDevice!.battery}%'
                    : '--',
                color: _selectedDevice != null && _selectedDevice!.battery > 20
                    ? Colors.green
                    : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPhoneLocationCard(),
        ],
      ),
    );
  }

  Widget _buildWeatherBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny, color: Colors.orange.shade700, size: 20),
          const SizedBox(width: 8),
          Text(
            '${_weather!.temperatureDisplay} - ${_weather!.description}',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade800,
            ),
          ),
          const Spacer(),
          Text(
            _weather!.cityName,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
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
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(height: 35, width: 1, color: Colors.grey.shade300);
  }

  Widget _buildPhoneLocationCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Phone GPS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  Text(
                    _phonePosition != null
                        ? '${_phonePosition!.latitude.toStringAsFixed(4)}, '
                            '${_phonePosition!.longitude.toStringAsFixed(4)}'
                        : 'Tap to get your location',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _isLoadingLocation ? null : _getPhoneLocation,
              icon: _isLoadingLocation
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: const Text('Locate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
