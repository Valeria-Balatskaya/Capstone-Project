import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/device.dart';
import '../models/device_history.dart';
import '../services/device_service.dart';
import '../widgets/app_drawer.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final DeviceService _deviceService = DeviceService();
  List<Device> _devices = [];
  Device? _selectedDevice;
  List<DeviceHistory> _history = [];
  Map<String, dynamic>? _statistics;
  bool _isLoading = true;
  String _timeRange = '7d';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _deviceService.watchDevices().listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
          if (_selectedDevice == null && devices.isNotEmpty) {
            _selectedDevice = devices.first;
            _loadDeviceAnalytics();
          }
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _loadDeviceAnalytics() async {
    if (_selectedDevice == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      int limit;
      DateTime? since;
      final now = DateTime.now();
      
      switch (_timeRange) {
        case '24h':
          limit = 24;
          since = now.subtract(const Duration(hours: 24));
          break;
        case '7d':
          limit = 168;
          since = now.subtract(const Duration(days: 7));
          break;
        case '30d':
          limit = 720;
          since = now.subtract(const Duration(days: 30));
          break;
        default:
          limit = 168;
          since = now.subtract(const Duration(days: 7));
      }
      
      final history = await _deviceService.getDeviceHistory(
        _selectedDevice!.id,
        limit: limit,
        since: since,
      );
      
      final stats = _calculateStatisticsFromHistory(history);
      
      setState(() {
        _history = history;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  Map<String, dynamic> _calculateStatisticsFromHistory(List<DeviceHistory> history) {
    if (history.isEmpty) {
      return {
        'averageBattery': 0,
        'averageAccuracy': 0.0,
        'averageSignal': 0,
        'totalDataPoints': 0,
      };
    }
    
    final batteries = history.map((h) => h.battery).toList();
    final accuracies = history.map((h) => h.accuracy).toList();
    final signals = history.map((h) => h.signalStrength).toList();
    
    return {
      'averageBattery': (batteries.reduce((a, b) => a + b) / batteries.length).round(),
      'averageAccuracy': accuracies.reduce((a, b) => a + b) / accuracies.length,
      'averageSignal': (signals.reduce((a, b) => a + b) / signals.length).round(),
      'totalDataPoints': history.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDeviceAnalytics,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'analytics'),
      body: _isLoading && _devices.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No devices to analyze',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a device to see analytics',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeviceSelector(),
          const SizedBox(height: 16),
          _buildTimeRangeSelector(),
          const SizedBox(height: 20),
          if (_statistics != null) ...[
            _buildOverviewCards(),
            const SizedBox(height: 20),
          ],
          if (_history.isNotEmpty) ...[
            _buildBatteryChart(),
            const SizedBox(height: 20),
            _buildSignalChart(),
            const SizedBox(height: 20),
            _buildAccuracyChart(),
            const SizedBox(height: 20),
            _buildHourlyActivityChart(),
          ] else if (!_isLoading)
            _buildNoDataCard(),
        ],
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Device',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButton<Device>(
              value: _selectedDevice,
              isExpanded: true,
              underline: const SizedBox(),
              items: _devices.map((device) {
                return DropdownMenuItem<Device>(
                  value: device,
                  child: Row(
                    children: [
                      Icon(
                        Icons.sensors,
                        size: 20,
                        color: device.status == 'online' ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(device.name)),
                      Text(
                        '${device.battery}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (device) {
                setState(() => _selectedDevice = device);
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
          _buildTimeChip('24h', 'Last 24 Hours'),
          const SizedBox(width: 8),
          _buildTimeChip('7d', 'Last 7 Days'),
          const SizedBox(width: 8),
          _buildTimeChip('30d', 'Last 30 Days'),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String value, String label) {
    final isSelected = _timeRange == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _timeRange = value);
        _loadDeviceAnalytics();
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: Colors.blue.shade100,
      checkmarkColor: Colors.blue.shade800,
    );
  }

  Widget _buildOverviewCards() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          icon: Icons.battery_charging_full,
          title: 'Avg Battery',
          value: '${_statistics!['averageBattery'] ?? '-'}%',
          color: Colors.green,
        ),
        _buildStatCard(
          icon: Icons.signal_cellular_alt,
          title: 'Avg Signal',
          value: '${_statistics!['averageSignal'] ?? '-'}%',
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.gps_fixed,
          title: 'Avg Accuracy',
          value: '${(_statistics!['averageAccuracy'] as double?)?.toStringAsFixed(1) ?? '-'}m',
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.data_usage,
          title: 'Data Points',
          value: '${_statistics!['totalDataPoints'] ?? 0}',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatteryChart() {
    return _buildChartCard(
      title: 'Battery Level Over Time',
      icon: Icons.battery_charging_full,
      color: Colors.green,
      spots: _history.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value.battery.toDouble());
      }).toList().reversed.toList(),
      yAxisLabel: '%',
      maxY: 100,
    );
  }

  Widget _buildSignalChart() {
    return _buildChartCard(
      title: 'Signal Strength Over Time',
      icon: Icons.signal_cellular_alt,
      color: Colors.blue,
      spots: _history.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value.signalStrength.toDouble());
      }).toList().reversed.toList(),
      yAxisLabel: '%',
      maxY: 100,
    );
  }

  Widget _buildAccuracyChart() {
    final maxAccuracy = _history.isEmpty
        ? 20.0
        : _history.map((h) => h.accuracy).reduce((a, b) => a > b ? a : b) + 5;

    return _buildChartCard(
      title: 'Position Accuracy Over Time',
      icon: Icons.gps_fixed,
      color: Colors.orange,
      spots: _history.asMap().entries.map((e) {
        return FlSpot(e.key.toDouble(), e.value.accuracy);
      }).toList().reversed.toList(),
      yAxisLabel: 'm',
      maxY: maxAccuracy,
      invertColors: true,
    );
  }

  Widget _buildChartCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<FlSpot> spots,
    required String yAxisLabel,
    required double maxY,
    bool invertColors = false,
  }) {
    if (spots.length < 2) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade200,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: maxY / 4,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}$yAxisLabel',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots.take(100).toList(),
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withValues(alpha: 0.1),
                      ),
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

  Widget _buildHourlyActivityChart() {
    final hourlyData = List.filled(24, 0);
    for (var h in _history) {
      hourlyData[h.timestamp.hour]++;
    }

    final maxCount = hourlyData.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxCount == 0) return const SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.access_time, color: Colors.purple, size: 20),
                SizedBox(width: 8),
                Text(
                  'Activity by Hour',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxCount + 1,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value % 6 == 0) {
                            return Text(
                              '${value.toInt()}h',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 10,
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 20,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: hourlyData.asMap().entries.map((e) {
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.toDouble(),
                          color: Colors.purple.withValues(alpha: 0.7),
                          width: 8,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.analytics, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No data available for this period',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Data is collected automatically as the device operates',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
