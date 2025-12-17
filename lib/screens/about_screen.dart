import 'package:flutter/material.dart';
import '../widgets/app_drawer.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About LoraTrack'),
      ),
      drawer: const AppDrawer(currentRoute: 'about'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAppLogo(),
            const SizedBox(height: 24),
            _buildAppInfo(),
            const SizedBox(height: 24),
            _buildFeaturesCard(),
            const SizedBox(height: 16),
            _buildTechStackCard(),
            const SizedBox(height: 16),
            _buildTeamCard(),
            const SizedBox(height: 16),
            _buildGrade5FeaturesCard(),
            const SizedBox(height: 24),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade400, Colors.blue.shade800],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: const Icon(
        Icons.location_on,
        size: 80,
        color: Colors.white,
      ),
    );
  }

  Widget _buildAppInfo() {
    return Column(
      children: [
        const Text(
          'LoraTrack',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Version 2.0.0',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Indoor Position Tracking Using LoRaWAN',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFeaturesCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Key Features',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFeatureItem(
              Icons.gps_fixed,
              'Real-Time Tracking',
              'Live position updates for all devices',
            ),
            _buildFeatureItem(
              Icons.psychology,
              'AI-Powered Insights',
              'ML-based anomaly detection and predictions',
            ),
            _buildFeatureItem(
              Icons.cloud_sync,
              'Cloud Sync',
              'Automatic Firebase synchronization',
            ),
            _buildFeatureItem(
              Icons.analytics,
              'Analytics Dashboard',
              'Charts and statistics visualization',
            ),
            _buildFeatureItem(
              Icons.notifications_active,
              'Smart Notifications',
              'Battery, signal, and device alerts',
            ),
            _buildFeatureItem(
              Icons.wb_sunny,
              'Weather Integration',
              'Environmental context for tracking',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
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
    );
  }

  Widget _buildTechStackCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Technical Stack',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTechItem('Framework', 'Flutter / Dart'),
            _buildTechItem('Backend', 'Firebase (Auth, Firestore)'),
            _buildTechItem('Protocol', 'LoRaWAN'),
            _buildTechItem('Server', 'ChirpStack'),
            _buildTechItem('Positioning', 'RSSI Trilateration'),
            _buildTechItem('AI/ML', 'Statistical Analysis & Pattern Recognition'),
            _buildTechItem('Charts', 'fl_chart'),
            _buildTechItem('Maps', 'flutter_map + OpenStreetMap'),
          ],
        ),
      ),
    );
  }

  Widget _buildTechItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Colors.purple.shade600),
                const SizedBox(width: 8),
                const Text(
                  'Capstone Team',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTeamMember('Vladyslav Dubenchuk'),
            _buildTeamMember('Valeriia Balatska'),
            _buildTeamMember('Daniyar Zhumataev'),
            _buildTeamMember('Kuzma Martysiuk'),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMember(String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              name[0],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            name,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildGrade5FeaturesCard() {
    return Card(
      elevation: 2,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '5',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Grade 5 Features',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildGradeFeature(
              Icons.check_circle,
              'AI/ML Integration',
              'Z-score anomaly detection, linear regression trends, pattern recognition',
            ),
            _buildGradeFeature(
              Icons.check_circle,
              'Sensor Integration',
              'GPS location service, step counter with activity tracking',
            ),
            _buildGradeFeature(
              Icons.check_circle,
              'External API',
              'OpenWeatherMap integration with tracking advice',
            ),
            _buildGradeFeature(
              Icons.check_circle,
              'Analytics & Charts',
              'Interactive charts, performance scores, device statistics',
            ),
            _buildGradeFeature(
              Icons.check_circle,
              'Smart Notifications',
              'Context-aware alerts for battery, signal, and device status',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeFeature(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.green.shade600),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 12),
        Text(
          'Mobile Systems Course - Capstone Project',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2025 LoraTrack Team',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite, size: 14, color: Colors.red.shade400),
            const SizedBox(width: 4),
            Text(
              'Built with Flutter',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
