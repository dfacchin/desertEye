import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const DesertEyeApp());
}

class DesertEyeApp extends StatelessWidget {
  const DesertEyeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DesertEye',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
