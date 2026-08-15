import 'package:flutter/material.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fortschritt'),
      ),
      body: const Center(
        child: Text(
          'Dein Fortschritt',
          style: TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}