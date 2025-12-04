import 'package:flutter/material.dart';
import 'switch_ar.dart';
void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: switch_AR()
      );
  }
}
