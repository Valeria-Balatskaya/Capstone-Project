import 'package:flutter/material.dart';
import 'live_tracking_screen.dart';

class DeviceDetailScreen extends StatelessWidget {
  final Map<String, dynamic> device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    final bool isOnline = device['status'] == 'online';
    final int battery = device['battery'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(device['name']),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Go to Main Screen',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const LiveTrackingScreen(),
                ),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isOnline
                        ? [Colors.green.shade400, Colors.green.shade700]
                        : [Colors.grey.shade400, Colors.grey.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    Icon(
                      isOnline ? Icons.sensors : Icons.sensors_off,
                      size: 60,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      device['status'].toString().toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Last seen: ${device['lastSeen']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildSectionTitle('Device Information'),
            const SizedBox(height: 10),
            _buildInfoTile(
              icon: Icons.fingerprint,
              title: 'Device ID',
              value: device['id'],
            ),
            _buildInfoTile(
              icon: Icons.label,
              title: 'Device Name',
              value: device['name'],
            ),
            if (device['description'] != null && device['description'].isNotEmpty)
              _buildInfoTile(
                icon: Icons.description,
                title: 'Description',
                value: device['description'],
              ),

            const SizedBox(height: 20),

            _buildSectionTitle('Technical Details'),
            const SizedBox(height: 10),
            _buildInfoTile(
              icon: Icons.battery_charging_full,
              title: 'Battery Level',
              value: '$battery%',
              color: _getBatteryColor(battery),
            ),
            _buildInfoTile(
              icon: Icons.gps_fixed,
              title: 'Position Accuracy',
              value: '${device['accuracy']} meters',
            ),
            _buildInfoTile(
              icon: Icons.access_time,
              title: 'Last Update',
              value: device['lastSeen'],
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isOnline
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tracking feature - Coming in Week 7'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.my_location),
                label: const Text('Track on Map'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
    Color? color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.blue.shade800),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
      ),
    );
  }

  Color _getBatteryColor(int battery) {
    if (battery > 50) return Colors.green;
    if (battery > 20) return Colors.orange;
    return Colors.red;
  }
}
