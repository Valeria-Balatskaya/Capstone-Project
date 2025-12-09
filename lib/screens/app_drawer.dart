import 'package:flutter/material.dart';
import 'live_tracking_screen.dart';
import 'device_list_screen.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'analytics_screen.dart';
import 'ai_assistant_screen.dart';
import 'profile_screen.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;

  const AppDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
            leading: Icon(
              Icons.my_location,
              color: currentRoute == 'position' ? Colors.blue : Colors.grey.shade700,
            ),
            title: Text(
              'Position',
              style: TextStyle(
                fontWeight: currentRoute == 'position' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: currentRoute == 'position',
            selectedTileColor: Colors.blue.shade50,
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != 'position') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LiveTrackingScreen(),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.devices,
              color: currentRoute == 'devices' ? Colors.blue : Colors.grey.shade700,
            ),
            title: Text(
              'Devices',
              style: TextStyle(
                fontWeight: currentRoute == 'devices' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: currentRoute == 'devices',
            selectedTileColor: Colors.blue.shade50,
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != 'devices') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DeviceListScreen(),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.analytics,
              color: currentRoute == 'analytics' ? Colors.blue : Colors.grey.shade700,
            ),
            title: Text(
              'Analytics',
              style: TextStyle(
                fontWeight: currentRoute == 'analytics' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: currentRoute == 'analytics',
            selectedTileColor: Colors.blue.shade50,
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != 'analytics') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AnalyticsScreen(),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.psychology,
              color: currentRoute == 'ai' ? Colors.blue : Colors.grey.shade700,
            ),
            title: Text(
              'AI Assistant',
              style: TextStyle(
                fontWeight: currentRoute == 'ai' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: currentRoute == 'ai',
            selectedTileColor: Colors.blue.shade50,
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != 'ai') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AIAssistantScreen(),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.settings,
              color: currentRoute == 'settings' ? Colors.blue : Colors.grey.shade700,
            ),
            title: Text(
              'Settings',
              style: TextStyle(
                fontWeight: currentRoute == 'settings' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: currentRoute == 'settings',
            selectedTileColor: Colors.blue.shade50,
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != 'settings') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.person,
              color: currentRoute == 'profile' ? Colors.blue : Colors.grey.shade700,
            ),
            title: Text(
              'Profile',
              style: TextStyle(
                fontWeight: currentRoute == 'profile' ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            selected: currentRoute == 'profile',
            selectedTileColor: Colors.blue.shade50,
            onTap: () {
              Navigator.pop(context);
              if (currentRoute != 'profile') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                );
              }
            },
          ),
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
    );
  }
}
