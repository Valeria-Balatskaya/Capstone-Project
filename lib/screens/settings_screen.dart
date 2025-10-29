import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import 'app_drawer.dart';
import 'live_tracking_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  
  final _serverUrlController = TextEditingController();
  final _apiTokenController = TextEditingController();
  final _mqttBrokerController = TextEditingController();
  
  bool _notificationsEnabled = true;
  double _updateInterval = 5.0; 
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final settings = await _settingsService.loadSettings();
    
    setState(() {
      _serverUrlController.text = settings.serverUrl;
      _apiTokenController.text = settings.apiToken;
      _mqttBrokerController.text = settings.mqttBroker;
      _updateInterval = settings.updateInterval.toDouble();
      _notificationsEnabled = settings.notificationsEnabled;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final settings = AppSettings(
      serverUrl: _serverUrlController.text.trim(),
      apiToken: _apiTokenController.text.trim(),
      mqttBroker: _mqttBrokerController.text.trim(),
      updateInterval: _updateInterval.toInt(),
      notificationsEnabled: _notificationsEnabled,
    );

    await _settingsService.saveSettings(settings);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiTokenController.dispose();
    _mqttBrokerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
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
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'settings'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildSectionTitle('Server Configuration'),
            const SizedBox(height: 10),
            
            TextFormField(
              controller: _serverUrlController,
              decoration: InputDecoration(
                labelText: 'ChirpStack Server URL',
                hintText: 'http://192.168.1.100:8080',
                prefixIcon: const Icon(Icons.cloud),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                helperText: 'Your ChirpStack server address',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter server URL';
                }
                if (!value.startsWith('http://') && !value.startsWith('https://')) {
                  return 'URL must start with http:// or https://';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _apiTokenController,
              decoration: InputDecoration(
                labelText: 'API Token',
                hintText: 'Enter your ChirpStack API token',
                prefixIcon: const Icon(Icons.vpn_key),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                helperText: 'Authentication token for API access',
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter API token';
                }
                if (value.length < 10) {
                  return 'Token appears too short';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _mqttBrokerController,
              decoration: InputDecoration(
                labelText: 'MQTT Broker',
                hintText: 'mqtt://192.168.1.100:1883',
                prefixIcon: const Icon(Icons.router),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                helperText: 'MQTT broker for real-time updates',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter MQTT broker address';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 30),
            
            _buildSectionTitle('Tracking Settings'),
            const SizedBox(height: 10),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Position Update Interval',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${_updateInterval.toInt()} sec',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Slider(
                      value: _updateInterval,
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '${_updateInterval.toInt()}s',
                      onChanged: (value) {
                        setState(() => _updateInterval = value);
                      },
                    ),
                    Text(
                      'How often to fetch new position data',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: SwitchListTile(
                title: const Text('Enable Notifications'),
                subtitle: const Text('Receive alerts and position updates'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
                secondary: Icon(
                  Icons.notifications,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            
            const SizedBox(height: 30),
            
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Connection test - Coming in Week 8'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Test Connection'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                side: BorderSide(color: Colors.blue.shade800),
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
}
