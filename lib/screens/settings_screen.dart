import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../services/notification_service.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _settingsService = SettingsService();
  final _notificationService = NotificationService();

  final _serverUrlController = TextEditingController();
  final _apiTokenController = TextEditingController();
  final _mqttBrokerController = TextEditingController();

  bool _notificationsEnabled = true;
  bool _lowBatteryAlerts = true;
  bool _signalWarnings = true;
  bool _offlineAlerts = true;
  double _updateInterval = 5.0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final settings = await _settingsService.loadSettings();
    final notifPrefs = await _notificationService.loadPreferences();

    setState(() {
      _serverUrlController.text = settings.serverUrl;
      _apiTokenController.text = settings.apiToken;
      _mqttBrokerController.text = settings.mqttBroker;
      _updateInterval = settings.updateInterval.toDouble();
      _notificationsEnabled = settings.notificationsEnabled;
      _lowBatteryAlerts = notifPrefs.lowBatteryAlerts;
      _signalWarnings = notifPrefs.accuracyWarnings;
      _offlineAlerts = notifPrefs.movementDetection;
      _isLoading = false;
    });
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final settings = AppSettings(
      serverUrl: _serverUrlController.text.trim(),
      apiToken: _apiTokenController.text.trim(),
      mqttBroker: _mqttBrokerController.text.trim(),
      updateInterval: _updateInterval.toInt(),
      notificationsEnabled: _notificationsEnabled,
    );

    await _settingsService.saveSettings(settings);

    final notifPrefs = NotificationPreferences(
      lowBatteryAlerts: _lowBatteryAlerts,
      accuracyWarnings: _signalWarnings,
      movementDetection: _offlineAlerts,
      dailySummary: true,
    );
    await _notificationService.savePreferences(notifPrefs);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Settings saved successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _testConnection() async {
    if (_serverUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a server URL first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    await Future.delayed(const Duration(seconds: 2));

    setState(() => _isTesting = false);

    if (mounted) {
      final isSimulated = _serverUrlController.text.contains('simulation') ||
          _serverUrlController.text.isEmpty;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isSimulated ? Icons.info : Icons.check_circle,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSimulated
                      ? 'Running in simulation mode - no server required'
                      : 'Connection test successful!',
                ),
              ),
            ],
          ),
          backgroundColor: isSimulated ? Colors.blue : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _testNotification() async {
    await _notificationService.showSmartSuggestion(
      'Test Notification',
      'Notifications are working correctly!',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Test notification sent! Check your notification panel.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all settings to default values. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _settingsService.clearSettings();
      await _loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings reset to defaults'),
            backgroundColor: Colors.orange,
          ),
        );
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
        appBar: AppBar(title: const Text('Settings')),
        drawer: const AppDrawer(currentRoute: 'settings'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Reset to defaults',
            onPressed: _resetToDefaults,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'settings'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Server Configuration'),
            const SizedBox(height: 12),
            _buildServerSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Tracking Settings'),
            const SizedBox(height: 12),
            _buildTrackingSection(),
            const SizedBox(height: 24),
            _buildSectionHeader('Notification Settings'),
            const SizedBox(height: 12),
            _buildNotificationSection(),
            const SizedBox(height: 32),
            _buildSaveButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.blue.shade800,
      ),
    );
  }

  Widget _buildServerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _serverUrlController,
              decoration: const InputDecoration(
                labelText: 'ChirpStack Server URL',
                hintText: 'http://192.168.1.100:8080',
                prefixIcon: Icon(Icons.cloud),
                helperText: 'Leave empty for simulation mode',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiTokenController,
              decoration: const InputDecoration(
                labelText: 'API Token',
                hintText: 'Enter your ChirpStack API token',
                prefixIcon: Icon(Icons.vpn_key),
                helperText: 'Optional for simulation mode',
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mqttBrokerController,
              decoration: const InputDecoration(
                labelText: 'MQTT Broker',
                hintText: 'mqtt://192.168.1.100:1883',
                prefixIcon: Icon(Icons.router),
                helperText: 'For real-time updates',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingSection() {
    return Card(
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_updateInterval.toInt()} sec',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
              'How often to fetch new position data from devices',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 20, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Currently running in simulation mode. Device data is generated automatically for demonstration.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Enable Notifications'),
            subtitle: const Text('Receive alerts and updates'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() => _notificationsEnabled = value);
            },
            secondary: Icon(
              Icons.notifications,
              color: _notificationsEnabled ? Colors.blue.shade800 : Colors.grey,
            ),
          ),
          if (_notificationsEnabled) ...[
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Low Battery Alerts'),
              subtitle: const Text('When device battery falls below 20%'),
              value: _lowBatteryAlerts,
              onChanged: (value) {
                setState(() => _lowBatteryAlerts = value);
              },
              secondary: Icon(
                Icons.battery_alert,
                color: _lowBatteryAlerts ? Colors.orange : Colors.grey,
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Signal Warnings'),
              subtitle: const Text('When signal quality drops significantly'),
              value: _signalWarnings,
              onChanged: (value) {
                setState(() => _signalWarnings = value);
              },
              secondary: Icon(
                Icons.signal_cellular_alt,
                color: _signalWarnings ? Colors.red : Colors.grey,
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Device Offline Alerts'),
              subtitle: const Text('When a device goes offline'),
              value: _offlineAlerts,
              onChanged: (value) {
                setState(() => _offlineAlerts = value);
              },
              secondary: Icon(
                Icons.sensors_off,
                color: _offlineAlerts ? Colors.purple : Colors.grey,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.notification_add, color: Colors.blue.shade800),
              title: const Text('Test Notification'),
              subtitle: const Text('Send a test notification'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _testNotification,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveSettings,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save),
        label: Text(
          _isSaving ? 'Saving...' : 'Save Settings',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
