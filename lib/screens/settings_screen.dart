import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/chirpstack_service.dart';
import '../services/auth_service.dart';
import '../services/device_service.dart';
import '../services/firestore_service.dart';
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
  final _chirpStackService = ChirpStackService();
  final _authService = AuthService();
  final _deviceService = DeviceService();
  final _firestoreService = FirestoreService();

  final _serverUrlController = TextEditingController();
  final _apiTokenController = TextEditingController();
  final _mqttBrokerController = TextEditingController();

  bool _notificationsEnabled = true;
  double _updateInterval = 5.0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;
  bool _isSyncing = false;
  Map<String, dynamic>? _syncStatus;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSyncStatus();
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

  Future<void> _loadSyncStatus() async {
    if (_authService.isLoggedIn) {
      final status = await _firestoreService.getSyncStatus();
      if (mounted) {
        setState(() => _syncStatus = status);
      }
    }
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

  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields correctly'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    final result = await _chirpStackService.testConnection(
      serverUrl: _serverUrlController.text.trim(),
      apiToken: _apiTokenController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                result['success'] ? Icons.check_circle : Icons.error,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(result['message'])),
            ],
          ),
          backgroundColor: result['success'] ? Colors.green : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() => _isTesting = false);
    }
  }

  Future<void> _syncToCloud() async {
    if (!_authService.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to sync data to cloud'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      await _deviceService.syncWithCloud();
      await _loadSyncStatus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Data synced to cloud successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
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
            // Cloud Sync Section (NEW!)
            if (_authService.isLoggedIn) ...[
              _buildSectionTitle('Cloud Synchronization'),
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
                        children: [
                          Icon(
                            Icons.cloud,
                            color: Colors.blue.shade800,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Firebase Cloud Sync',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _syncStatus?['synced'] == true
                                      ? 'Status: Synced'
                                      : 'Status: Not synced',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_syncStatus != null && _syncStatus!['synced'] == true) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Devices in cloud:',
                              style: TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${_syncStatus!['deviceCount']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (_syncStatus!['lastSync'] != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Last synced:',
                                style: TextStyle(fontSize: 13),
                              ),
                              Text(
                                _formatDateTime(_syncStatus!['lastSync']),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _syncToCloud,
                          icon: _isSyncing
                              ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.sync),
                          label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],

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
                if (!value.startsWith('http://') &&
                    !value.startsWith('https://')) {
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

            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.wifi_tethering),
                label: Text(
                  _isTesting ? 'Testing Connection...' : 'Test Connection',
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: _isTesting ? Colors.grey : Colors.blue.shade800,
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

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
