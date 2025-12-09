import 'package:flutter/material.dart';
import '../services/ai_service.dart';
import '../services/device_service.dart';
import 'app_drawer.dart';
import 'live_tracking_screen.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final AIService _aiService = AIService();
  final DeviceService _deviceService = DeviceService();

  List<Map<String, dynamic>> devices = [];
  String? selectedDeviceId;
  List<AISuggestion> suggestions = [];
  Map<String, dynamic>? performanceScore;
  bool _isLoading = true;
  String? contextAnalysis;

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
      await _loadAISuggestions();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadAISuggestions() async {
    if (selectedDeviceId == null) return;

    try {
      final aiSuggestions = await _aiService.generateSmartSuggestions(selectedDeviceId!);
      final score = await _aiService.generatePerformanceScore(selectedDeviceId!);
      final context = await _aiService.analyzeLocationContext(51.7592, 19.4560, selectedDeviceId!);

      setState(() {
        suggestions = aiSuggestions;
        performanceScore = score;
        contextAnalysis = context;
      });
    } catch (e) {
      // Handle devices with no data yet
      print('AI Assistant Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No data available for this device.\n\nGenerate analytics data first!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      setState(() {
        suggestions = [];
        performanceScore = null;
        contextAnalysis = '📊 No data available yet.\n\nVisit Analytics screen and tap "Generate Sample Data" to create history for this device.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('AI Assistant'),
          backgroundColor: Colors.purple.shade800,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI Assistant'),
        backgroundColor: Colors.purple.shade800,
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
      drawer: const AppDrawer(currentRoute: 'ai'),
      body: devices.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.psychology_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 20),
            Text('No devices available for AI analysis'),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDeviceSelector(),
            const SizedBox(height: 16),
            if (contextAnalysis != null) _buildContextCard(),
            const SizedBox(height: 16),
            if (performanceScore != null) _buildPerformanceCard(),
            const SizedBox(height: 20),
            const Text(
              '💡 Smart Suggestions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'AI-powered insights and recommendations',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (suggestions.isEmpty && performanceScore == null)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.analytics, size: 48, color: Colors.orange.shade700),
                      const SizedBox(height: 12),
                      const Text(
                        'No Data Available',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This device needs historical data to generate AI insights.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushReplacementNamed(context, '/analytics');
                        },
                        icon: const Icon(Icons.add_chart),
                        label: const Text('Go to Analytics'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (suggestions.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Generate device history data to receive AI suggestions.'),
                ),
              )
            else
              ...suggestions.map((suggestion) => _buildSuggestionCard(suggestion)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceSelector() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Device for Analysis',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
                setState(() => selectedDeviceId = value);
                _loadAISuggestions();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextCard() {
    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.blue.shade800, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                contextAnalysis!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final score = performanceScore!;
    final grade = score['grade'];
    final totalScore = score['score'];

    Color gradeColor;
    if (totalScore >= 80) {
      gradeColor = Colors.green;
    } else if (totalScore >= 60) {
      gradeColor = Colors.orange;
    } else {
      gradeColor = Colors.red;
    }

    return Card(
      elevation: 3,
      color: gradeColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'AI Performance Analysis',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: gradeColor, width: 3),
                  ),
                  child: Text(
                    grade,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: gradeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$totalScore / 100 Points',
              style: TextStyle(fontSize: 18, color: gradeColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildScoreDetail('Accuracy', score['accuracyScore'], Icons.gps_fixed),
                _buildScoreDetail('Signal', score['signalScore'], Icons.signal_cellular_alt),
                _buildScoreDetail('Battery', score['batteryScore'], Icons.battery_charging_full),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreDetail(String label, int value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.grey.shade700),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSuggestionCard(AISuggestion suggestion) {
    IconData icon;
    Color color;

    switch (suggestion.iconType) {
      case IconType.warning:
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case IconType.alert:
        icon = Icons.error;
        color = Colors.red;
        break;
      case IconType.success:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case IconType.prediction:
        icon = Icons.psychology;
        color = Colors.purple;
        break;
      default:
        icon = Icons.info;
        color = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(
          suggestion.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            suggestion.description,
            style: const TextStyle(fontSize: 13),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}