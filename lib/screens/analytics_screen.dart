import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/analytics_service.dart';
import '../services/device_service.dart';
import '../models/device_history.dart';
import 'app_drawer.dart';
import 'live_tracking_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final AnalyticsService _analyticsService = AnalyticsService();
  final DeviceService _deviceService = DeviceService();

  List<Map<String, dynamic>> devices = [];
  String? selectedDeviceId;
  List<DeviceHistory> history = [];
  Map<String, dynamic> statistics = {};
  bool _isLoading = true;
  String _timeRange = '24h';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final loadedDevices = await _deviceService.loadDevices();
    setState(() {
      devices = loadedDevices;
      if (devices.isNotEmpty && selectedDeviceId == null) {
        selectedDeviceId = devices.first['id'];
      }
    });

    if (selectedDeviceId != null) {
      await _loadDeviceAnalytics();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadDeviceAnalytics() async {
    if (selectedDeviceId == null) return;

    DateTime? since;
    switch (_timeRange) {
      case '24h':
        since = DateTime.now().subtract(const Duration(hours: 24));
        break;
      case '7d':
        since = DateTime.now().subtract(const Duration(days: 7));
        break;
      case '30d':
        since = DateTime.now().subtract(const Duration(days: 30));
        break;
      default:
        since = null;
    }

    final deviceHistory = await _analyticsService.getHistory(selectedDeviceId!, since: since, limit: 100);
    final stats = await _analyticsService.getStatistics(selectedDeviceId!, since: since);

    setState(() {
      history = deviceHistory;
      statistics = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (devices.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Analytics'),
          backgroundColor: Colors.blue.shade800,
          foregroundColor: Colors.white,
        ),
        drawer: const AppDrawer(currentRoute: 'analytics'),
        body: const Center(
          child: Text('No devices available for analytics'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LiveTrackingScreen()),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'analytics'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceSelector(),
            const SizedBox(height: 16),
            _buildTimeRangeSelector(),
            const SizedBox(height: 20),
            _buildStatisticsCards(),
            const SizedBox(height: 20),
            _buildAccuracyChart(),
            const SizedBox(height: 20),
            _buildBatteryChart(),
            const SizedBox(height: 20),
            _buildSimulateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select Device', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: selectedDeviceId,
              isExpanded: true,
              items: devices.map((device) {
                return DropdownMenuItem<String>(
                  value: device['id'],
                  child: Text(device['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedDeviceId = value;
                });
                _loadDeviceAnalytics();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildTimeRangeChip('24h', 'Last 24 Hours'),
          _buildTimeRangeChip('7d', 'Last 7 Days'),
          _buildTimeRangeChip('30d', 'Last 30 Days'),
          _buildTimeRangeChip('all', 'All Time'),
        ],
      ),
    );
  }

  Widget _buildTimeRangeChip(String value, String label) {
    final isSelected = _timeRange == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _timeRange = value;
          });
          _loadDeviceAnalytics();
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.blue.shade100,
      ),
    );
  }

  Widget _buildStatisticsCards() {
    if (statistics.isEmpty || statistics['totalDataPoints'] == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No data available for this device. Click "Generate Sample Data" below.'),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Avg Accuracy', '${statistics['averageAccuracy'].toStringAsFixed(1)}m', Icons.gps_fixed, Colors.green)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Best Accuracy', '${statistics['bestAccuracy'].toStringAsFixed(1)}m', Icons.star, Colors.orange)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildStatCard('Avg Battery', '${statistics['averageBattery']}%', Icons.battery_charging_full, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _buildStatCard('Data Points', '${statistics['totalDataPoints']}', Icons.data_usage, Colors.purple)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccuracyChart() {
    if (history.isEmpty) {
      return const SizedBox();
    }

    final spots = history.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.accuracy);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Position Accuracy Over Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryChart() {
    if (history.isEmpty) {
      return const SizedBox();
    }

    final spots = history.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.battery.toDouble());
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Battery Level Over Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimulateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          if (selectedDeviceId != null) {
            await _analyticsService.simulateHistoryData(selectedDeviceId!);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Sample data generated! Refresh to see charts.'), backgroundColor: Colors.green),
            );
            await _loadDeviceAnalytics();
          }
        },
        icon: const Icon(Icons.science),
        label: const Text('Generate Sample Data'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.all(16),
        ),
      ),
    );
  }
}