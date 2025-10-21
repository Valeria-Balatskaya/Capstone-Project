import 'package:flutter/material.dart';
import 'screens/live_tracking_screen.dart';

void main() {
  runApp(const LoraTrackApp());
}

class LoraTrackApp extends StatelessWidget {
  const LoraTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoraTrack',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const LiveTrackingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
