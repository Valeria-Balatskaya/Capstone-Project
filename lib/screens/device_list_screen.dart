import 'package:flutter/material.dart';
import 'live_tracking_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  final List<Map<String, dynamic>> devices = [
    {
      'id': 'Device-001',
      'name': 'Tracking Tag 1',
      'status': 'online',
      'lastSeen': '2 min ago',
      'battery': 87,
      'accuracy': 5.2,
    },
    {
      'id': 'Device-002',
      'name': 'Tracking Tag 2',
      'status': 'online',
      'lastSeen': '5 min ago',
      'battery': 65,
      'accuracy': 8.1,
    },
    {
      'id': 'Device-003',
      'name': 'Tracking Tag 3',
      'status': 'offline',
      'lastSeen': '1 hour ago',
      'battery': 23,
      'accuracy': 0.0,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracked Devices'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Add Device - Coming in Week 4'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.blue.shade400, Colors.blue.shade800],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(
                    Icons.location_on,
                    size: 50,
                    color: Colors.white,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'LoraTrack',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'LoRaWAN Position Tracking',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.my_location, color: Colors.grey.shade700),
              title: const Text('Position'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LiveTrackingScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.devices, color: Colors.blue),
              title: const Text(
                'Devices',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              selected: true,
              selectedTileColor: Colors.blue.shade50,
              onTap: () {
                Navigator.pop(context); 
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: Colors.grey.shade700),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.info_outline, color: Colors.grey.shade700),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context); 
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AboutScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
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
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: devices.length,
              itemBuilder: (context, index) {
                final device = devices[index];
                return _buildDeviceCard(device);
              },
            ),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> device) {
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
                Text(
                  'Battery: $battery%',
                  style: TextStyle(
                    fontSize: 12,
                    color: _getBatteryColor(battery),
                  ),
                ),
                const SizedBox(width: 15),
                Icon(
                  Icons.gps_fixed,
                  size: 14,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 5),
                Text(
                  'Accuracy: ${device['accuracy']}m',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
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
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: ${device['name']}'),
              duration: const Duration(seconds: 2),
            ),
          );
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
