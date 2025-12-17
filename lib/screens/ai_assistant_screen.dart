import 'package:flutter/material.dart';
import '../models/device.dart';
import '../models/ai_models.dart';
import '../services/device_service.dart';
import '../services/ai_service.dart';
import '../widgets/app_drawer.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final DeviceService _deviceService = DeviceService();
  final AIService _aiService = AIService();
  
  List<Device> _devices = [];
  Device? _selectedDevice;
  List<AISuggestion> _suggestions = [];
  PerformanceScore? _performanceScore;
  bool _isLoading = true;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    _deviceService.watchDevices().listen((devices) {
      if (mounted) {
        setState(() {
          _devices = devices;
          if (_selectedDevice == null && devices.isNotEmpty) {
            _selectedDevice = devices.first;
            _analyzeDevice();
          }
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _analyzeDevice() async {
    if (_selectedDevice == null) return;
    
    setState(() => _isAnalyzing = true);
    
    try {
      final history = await _deviceService.getDeviceHistory(
        _selectedDevice!.id,
        limit: 200,
      );
      
      final suggestions = await _aiService.generateSmartSuggestions(
        _selectedDevice!,
        history,
      );
      
      final score = await _aiService.calculatePerformanceScore(
        _selectedDevice!,
        history,
      );
      
      setState(() {
        _suggestions = suggestions;
        _performanceScore = score;
        _isAnalyzing = false;
      });
    } catch (e) {
      setState(() => _isAnalyzing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isAnalyzing ? null : _analyzeDevice,
          ),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'ai'),
      body: _isLoading
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
          Icon(Icons.psychology, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No devices to analyze',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a device to get AI insights',
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
          if (_isAnalyzing)
            _buildAnalyzingCard()
          else ...[
            if (_performanceScore != null) _buildPerformanceCard(),
            const SizedBox(height: 20),
            _buildSuggestionsSection(),
          ],
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
            Row(
              children: [
                Icon(Icons.psychology, color: Colors.purple.shade800),
                const SizedBox(width: 8),
                Text(
                  'Select Device for Analysis',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                    ],
                  ),
                );
              }).toList(),
              onChanged: (device) {
                setState(() {
                  _selectedDevice = device;
                  _suggestions = [];
                  _performanceScore = null;
                });
                _analyzeDevice();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyzingCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Analyzing device data...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Running ML algorithms on historical data',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    final score = _performanceScore!;
    final gradeColor = _getGradeColor(score.grade);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [gradeColor.withValues(alpha: 0.8), gradeColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'AI Performance Score',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    score.grade,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: gradeColor,
                    ),
                  ),
                  Text(
                    '${score.overallScore}/100',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreItem('Accuracy', score.accuracyScore),
                _buildScoreItem('Signal', score.signalScore),
                _buildScoreItem('Battery', score.batteryScore),
                _buildScoreItem('Uptime', score.uptimeScore),
              ],
            ),
            const SizedBox(height: 16),
            if (score.summary.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  score.summary,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreItem(String label, int score) {
    return Column(
      children: [
        Text(
          '$score',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 24),
            const SizedBox(width: 8),
            const Text(
              'AI Suggestions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Intelligent recommendations based on data analysis',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        if (_suggestions.isEmpty)
          _buildNoSuggestionsCard()
        else
          ..._suggestions.map((s) => _buildSuggestionCard(s)),
      ],
    );
  }

  Widget _buildNoSuggestionsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.check_circle, size: 48, color: Colors.green.shade400),
            const SizedBox(height: 12),
            Text(
              'Everything looks good!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No issues detected. Your device is performing optimally.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionCard(AISuggestion suggestion) {
    final priorityColor = _getPriorityColor(suggestion.priority);
    final icon = _getSuggestionIcon(suggestion.type);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showSuggestionDetails(suggestion),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: priorityColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            suggestion.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getPriorityLabel(suggestion.priority),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      suggestion.description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Confidence: ${(suggestion.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuggestionDetails(AISuggestion suggestion) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final priorityColor = _getPriorityColor(suggestion.priority);
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: priorityColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSuggestionIcon(suggestion.type),
                        color: priorityColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getPriorityLabel(suggestion.priority),
                            style: TextStyle(
                              fontSize: 12,
                              color: priorityColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Analysis',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  suggestion.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Recommended Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...suggestion.actions.map((action) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade600,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          action,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'AI Confidence: ${(suggestion.confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getGradeColor(String grade) {
    if (grade.startsWith('A')) {
      return Colors.green.shade600;
    } else if (grade.startsWith('B')) {
      return Colors.lightGreen.shade600;
    } else if (grade.startsWith('C')) {
      return Colors.orange.shade600;
    } else {
      return Colors.red.shade600;
    }
  }

  Color _getPriorityColor(SuggestionPriority priority) {
    switch (priority) {
      case SuggestionPriority.critical:
        return Colors.red;
      case SuggestionPriority.high:
        return Colors.orange;
      case SuggestionPriority.medium:
        return Colors.blue;
      case SuggestionPriority.low:
        return Colors.green;
    }
  }

  String _getPriorityLabel(SuggestionPriority priority) {
    switch (priority) {
      case SuggestionPriority.critical:
        return 'CRITICAL';
      case SuggestionPriority.high:
        return 'HIGH';
      case SuggestionPriority.medium:
        return 'MEDIUM';
      case SuggestionPriority.low:
        return 'LOW';
    }
  }

  IconData _getSuggestionIcon(SuggestionType type) {
    switch (type) {
      case SuggestionType.batteryWarning:
        return Icons.battery_alert;
      case SuggestionType.signalIssue:
        return Icons.signal_cellular_connected_no_internet_4_bar;
      case SuggestionType.accuracyDegradation:
        return Icons.gps_off;
      case SuggestionType.anomalyDetected:
        return Icons.warning;
      case SuggestionType.performanceInsight:
        return Icons.insights;
      case SuggestionType.recommendation:
        return Icons.lightbulb;
      case SuggestionType.maintenance:
        return Icons.build;
      case SuggestionType.warning:
        return Icons.warning_amber;
      case SuggestionType.info:
        return Icons.info_outline;
      case SuggestionType.success:
        return Icons.check_circle;
      case SuggestionType.prediction:
        return Icons.trending_up;
      case SuggestionType.alert:
        return Icons.notification_important;
      case SuggestionType.insight:
        return Icons.psychology;
    }
  }
}
