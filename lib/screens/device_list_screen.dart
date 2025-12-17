import 'package:flutter/material.dart';
import '../models/device.dart';
import '../services/device_service.dart';
import '../services/location_service.dart';
import '../widgets/app_drawer.dart';
import 'device_detail_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final _deviceService = DeviceService();
  final _locationService = LocationService();
  final _searchController = TextEditingController();

  String _searchQuery = '';
  String _filterStatus = 'all';
  String _sortBy = 'name';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Device> _filterAndSortDevices(List<Device> devices) {
    var filtered = devices.where((device) {
      final matchesSearch = device.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          device.id.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesStatus = _filterStatus == 'all' ||
          (_filterStatus == 'online' && device.isOnline) ||
          (_filterStatus == 'offline' && !device.isOnline) ||
          (_filterStatus == 'lowBattery' && device.isLowBattery);

      return matchesSearch && matchesStatus;
    }).toList();

    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'battery':
        filtered.sort((a, b) => b.battery.compareTo(a.battery));
        break;
      case 'signal':
        filtered.sort((a, b) => b.signalStrength.compareTo(a.signalStrength));
        break;
      case 'recent':
        filtered.sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
        break;
    }

    return filtered;
  }

  void _showAddDeviceDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    bool useCurrentLocation = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Device'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Device Name',
                    hintText: 'e.g., Warehouse Tracker 1',
                    prefixIcon: Icon(Icons.label),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'e.g., Located in Building A',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Use current location'),
                  subtitle: const Text('Set device position to my GPS'),
                  value: useCurrentLocation,
                  onChanged: (value) {
                    setDialogState(() => useCurrentLocation = value ?? false);
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a device name'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                double? lat, lon;
                if (useCurrentLocation) {
                  final locationResult = await _locationService.getCurrentLocation();
                  if (locationResult.hasPosition) {
                    lat = locationResult.position!.latitude;
                    lon = locationResult.position!.longitude;
                  }
                }

                final device = await _deviceService.createDevice(
                  name: nameController.text.trim(),
                  description: descriptionController.text.trim(),
                  latitude: lat,
                  longitude: lon,
                );

                if (device != null && context.mounted) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Add Device'),
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Device "${nameController.text}" added!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter & Sort',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const Text('Filter by Status',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildFilterChip('All', 'all'),
                _buildFilterChip('Online', 'online'),
                _buildFilterChip('Offline', 'offline'),
                _buildFilterChip('Low Battery', 'lowBattery'),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Sort by',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildSortChip('Name', 'name'),
                _buildSortChip('Battery', 'battery'),
                _buildSortChip('Signal', 'signal'),
                _buildSortChip('Recent', 'recent'),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _sortBy = value);
        Navigator.pop(context);
      },
    );
  }

  Future<void> _deleteDevice(Device device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text(
          'Are you sure you want to delete "${device.name}"?\n\n'
          'This will also delete all history data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _deviceService.deleteDevice(device.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Device "${device.name}" deleted'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter & Sort',
            onPressed: _showFilterOptions,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Device',
            onPressed: _showAddDeviceDialog,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'devices'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search devices...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Device>>(
              stream: _deviceService.watchDevices(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final devices = snapshot.data ?? [];
                final filteredDevices = _filterAndSortDevices(devices);

                if (devices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.devices_other,
                            size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 20),
                        Text(
                          'No devices yet',
                          style: TextStyle(
                              fontSize: 18, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Tap + to add your first device',
                          style: TextStyle(
                              fontSize: 14, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showAddDeviceDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Device'),
                        ),
                      ],
                    ),
                  );
                }

                if (filteredDevices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'No devices match your search',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        TextButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                              _filterStatus = 'all';
                            });
                          },
                          child: const Text('Clear filters'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDevices.length,
                  itemBuilder: (context, index) {
                    final device = filteredDevices[index];
                    return _buildDeviceCard(device);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceDetailScreen(device: device),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? Colors.green.shade50
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sensors,
                  size: 32,
                  color: device.isOnline ? Colors.green : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.lastSeenFormatted,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatChip(
                          Icons.battery_std,
                          '${device.battery}%',
                          device.battery > 20 ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          Icons.signal_cellular_alt,
                          '${device.signalStrength}%',
                          device.signalStrength > 50
                              ? Colors.blue
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          Icons.gps_fixed,
                          '${device.accuracy.toStringAsFixed(1)}m',
                          device.accuracy < 10 ? Colors.green : Colors.orange,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: device.isOnline
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      device.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: device.isOnline
                            ? Colors.green.shade800
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteDevice(device);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
