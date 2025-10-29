import 'package:flutter/material.dart';
import 'app_drawer.dart';
import 'device_detail_screen.dart';
import 'live_tracking_screen.dart';
import '../services/device_service.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final DeviceService _deviceService = DeviceService();
  List<Map<String, dynamic>> devices = [];
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
      _isLoading = false;
    });
  }

  Future<void> _saveDevices() async {
    await _deviceService.saveDevices(devices);
  }

  void _showAddDeviceDialog() {
    final nameController = TextEditingController();
    final idController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Device'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'Device ID / DevEUI',
                  hintText: 'e.g., 0000000000000001',
                  prefixIcon: Icon(Icons.fingerprint),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  hintText: 'e.g., Tracking Tag 4',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'e.g., Warehouse asset tracker',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (idController.text.isNotEmpty && nameController.text.isNotEmpty) {
                setState(() {
                  devices.add({
                    'id': idController.text,
                    'name': nameController.text,
                    'description': descriptionController.text,
                    'status': 'offline',
                    'lastSeen': 'Never',
                    'battery': 0,
                    'accuracy': 0.0,
                  });
                });
                await _saveDevices();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Device "${nameController.text}" added!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Add Device'),
          ),
        ],
      ),
    );
  }

  void _showEditDeviceDialog(int index) {
    final device = devices[index];
    final nameController = TextEditingController(text: device['name']);
    final idController = TextEditingController(text: device['id']);
    final descriptionController = TextEditingController(
      text: device['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: idController,
                decoration: const InputDecoration(
                  labelText: 'Device ID / DevEUI',
                  prefixIcon: Icon(Icons.fingerprint),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Device Name',
                  prefixIcon: Icon(Icons.label),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (Optional)',
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (idController.text.isNotEmpty && nameController.text.isNotEmpty) {
                setState(() {
                  devices[index]['id'] = idController.text;
                  devices[index]['name'] = nameController.text;
                  devices[index]['description'] = descriptionController.text;
                });
                await _saveDevices();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Device "${nameController.text}" updated!'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(int index) {
    final deviceName = devices[index]['name'];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Device'),
        content: Text(
          'Are you sure you want to delete "$deviceName"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final deletedDevice = devices[index];
              setState(() {
                devices.removeAt(index);
              });
              await _saveDevices();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Device "$deviceName" deleted'),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: 'UNDO',
                    textColor: Colors.white,
                    onPressed: () async {
                      setState(() {
                        devices.insert(index, deletedDevice);
                      });
                      await _saveDevices();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Device restored'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDeviceOptions(int index) {
    final device = devices[index];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
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
            Text(
              device['name'],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            if (device['description'] != null && device['description'].isNotEmpty)
              Text(
                device['description'],
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.blue),
              title: const Text('View Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceDetailScreen(device: device),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Edit Device'),
              onTap: () {
                Navigator.pop(context);
                _showEditDeviceDialog(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Device'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmation(index);
              },
            ),
            const SizedBox(height: 10),
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
          title: const Text('Tracked Devices'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracked Devices'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Go to Main Screen',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LiveTrackingScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Device',
            onPressed: _showAddDeviceDialog,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'devices'),
      body: devices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.devices_other,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No devices found',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap + to add a device',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return _buildDeviceCard(device, index);
              },
            ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device, int index) {
    final bool isOnline = device['status'] == 'online';
    final int battery = device['battery'];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.shade50 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.sensors,
            size: 30,
            color: isOnline ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          device['name'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text('ID: ${device['id']}'),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 5),
                Text(
                  'Last seen: ${device['lastSeen']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Icon(
                  Icons.battery_std,
                  size: 14,
                  color: _getBatteryColor(battery),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Battery: $battery%',
                    style: TextStyle(
                      fontSize: 12,
                      color: _getBatteryColor(battery),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Icon(
                  Icons.gps_fixed,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    'Accuracy: ${device['accuracy']}m',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green.shade100 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            device['status'].toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isOnline ? Colors.green.shade800 : Colors.grey.shade700,
            ),
          ),
        ),
        onTap: () {
          _showDeviceOptions(index);
        },
        onLongPress: () {
          _showDeleteConfirmation(index);
        },
      ),
    );
  }

  Color _getBatteryColor(int battery) {
    if (battery > 50) return Colors.green;
    if (battery > 20) return Colors.orange;
    return Colors.red;
  }
}