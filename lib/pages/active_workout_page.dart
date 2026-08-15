import 'package:flutter/material.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final String workoutName;

  const ActiveWorkoutPage({
    super.key,
    required this.workoutName,
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutName),
      ),
      body: const Center(
        child: Text(
          'Dieser Trainingsplan enthält noch keine Übungen.',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}