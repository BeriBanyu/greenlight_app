import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';


void main() {
  runApp(const GreenLightApp());
}

class GreenLightApp extends StatelessWidget {
  const GreenLightApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GreenLight',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
        ),
        useMaterial3: true,
      ),
      home: const WelcomeScreen(),
    );
  }
}