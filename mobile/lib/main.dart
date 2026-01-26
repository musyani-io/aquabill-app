import 'package:flutter/material.dart';

void main() {
  runApp(const AquaBillApp());
}

class AquaBillApp extends StatelessWidget {
  const AquaBillApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AquaBill',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AquaBill'),
      ),
      body: const Center(
        child: Text('Welcome to AquaBill Mobile'),
      ),
    );
  }
}
