import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/device.dart';
import '../models/device_history.dart';
import '../services/device_service.dart';
import 'map_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen>
    with SingleTickerProviderStateMixin {
  final DeviceService _deviceService = DeviceService();
  late TabController _tabController;
  List<DeviceHistory> _history = [];
  bool _isLoading = true;
  Map<String, dynamic>? _statistics;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final history = await _deviceService.getDeviceHistory(
        widget.device.id,
        limit: 100,
      );
      final stats = await _deviceService.getDeviceStatistics(widget.device.id);
      setState(() {
        _history = history;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
    final isOnline = device.status == 'online';

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        backgroundColor: Colors.blue.shade800,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Details'),
            Tab(icon: Icon(Icons.map), text: 'Location'),
            Tab(icon: Icon(Icons.history), text: 'History'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(device, isOnline),
          _buildLocationTab(device),
          _buildHistoryTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(Device device, bool isOnline) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(device, isOnline),
          const SizedBox(height: 16),
          _buildMetricsCard(device),
          const SizedBox(height: 16),
          if (_statistics != null) _buildStatisticsCard(),
          const SizedBox(height: 16),
          _buildInfoCard(device),
        ],
      ),
    );
  }

  Widget _buildStatusCard(Device device, bool isOnline) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isOnline
                ? [Colors.green.shade400, Colors.green.shade700]
                : [Colors.grey.shade400, Colors.grey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              isOnline ? Icons.sensors : Icons.sensors_off,
              size: 60,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Text(
              device.status.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last seen: ${_formatDateTime(device.lastSeen)}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard(Device device) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Metrics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.battery_charging_full,
                    label: 'Battery',
                    value: '${device.battery}%',
                    color: _getBatteryColor(device.battery),
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.signal_cellular_alt,
                    label: 'Signal',
                    value: '${device.signalStrength}%',
                    color: _getSignalColor(device.signalStrength),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.gps_fixed,
                    label: 'Accuracy',
                    value: '${device.accuracy.toStringAsFixed(1)}m',
                    color: _getAccuracyColor(device.accuracy),
                  ),
                ),
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.location_on,
                    label: 'Position',
                    value: '${device.latitude.toStringAsFixed(4)}, ${device.longitude.toStringAsFixed(4)}',
                    color: Colors.blue,
                    small: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool small = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 11 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistics (Last 14 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildStatRow('Avg Battery', '${_statistics!['averageBattery'] ?? '-'}%'),
            _buildStatRow('Avg Accuracy', '${(_statistics!['averageAccuracy'] as double?)?.toStringAsFixed(1) ?? '-'}m'),
            _buildStatRow('Avg Signal', '${_statistics!['averageSignal'] ?? '-'}%'),
            _buildStatRow('Data Points', '${_statistics!['totalDataPoints'] ?? 0}'),
            _buildStatRow('Uptime', '${(_statistics!['uptimePercent'] as double?)?.toStringAsFixed(0) ?? '0'}%'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Device device) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Device Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Device ID', device.id),
            _buildInfoRow('Name', device.name),
            if (device.description.isNotEmpty)
              _buildInfoRow('Description', device.description),
            _buildInfoRow('Created', _formatDateTime(device.createdAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTab(Device device) {
    return Column(
      children: [
        Expanded(
          child: MapScreen(
            latitude: device.latitude,
            longitude: device.longitude,
            deviceName: device.name,
            accuracy: device.accuracy,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLocationInfo('Latitude', device.latitude.toStringAsFixed(6)),
                  _buildLocationInfo('Longitude', device.longitude.toStringAsFixed(6)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildLocationInfo('Accuracy', '${device.accuracy.toStringAsFixed(1)}m'),
                  _buildLocationInfo('Updated', _formatTimeAgo(device.lastSeen)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No history available',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHistoryChart(),
          const SizedBox(height: 20),
          Text(
            'Recent Activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 12),
          ..._history.take(20).map((h) => _buildHistoryItem(h)),
        ],
      ),
    );
  }

  Widget _buildHistoryChart() {
    if (_history.length < 2) return const SizedBox();

    final batterySpots = _history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.battery.toDouble());
    }).toList().reversed.toList();

    final signalSpots = _history.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.signalStrength.toDouble());
    }).toList().reversed.toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Trends',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade300,
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
                        interval: 25,
                        reservedSize: 35,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
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
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: batterySpots.take(50).toList(),
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.green.withValues(alpha: 0.1),
                      ),
                    ),
                    LineChartBarData(
                      spots: signalSpots.take(50).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.green, 'Battery'),
                const SizedBox(width: 24),
                _buildLegendItem(Colors.blue, 'Signal'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildHistoryItem(DeviceHistory history) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _formatDateTime(history.timestamp),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          _buildMiniMetric(Icons.battery_std, '${history.battery}%', _getBatteryColor(history.battery)),
          const SizedBox(width: 12),
          _buildMiniMetric(Icons.signal_cellular_alt, '${history.signalStrength}%', _getSignalColor(history.signalStrength)),
          const SizedBox(width: 12),
          _buildMiniMetric(Icons.gps_fixed, '${history.accuracy.toStringAsFixed(1)}m', _getAccuracyColor(history.accuracy)),
        ],
      ),
    );
  }

  Widget _buildMiniMetric(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Color _getBatteryColor(int battery) {
    if (battery > 60) return Colors.green;
    if (battery > 30) return Colors.orange;
    return Colors.red;
  }

  Color _getSignalColor(int signal) {
    if (signal > 70) return Colors.green;
    if (signal > 40) return Colors.orange;
    return Colors.red;
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy < 5) return Colors.green;
    if (accuracy < 15) return Colors.orange;
    return Colors.red;
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
