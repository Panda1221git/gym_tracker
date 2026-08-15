import 'package:flutter/material.dart';

import 'workout_templates_page.dart';

class WorkoutPage extends StatelessWidget {
  const WorkoutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training'),
      ),
      body: Center(
        child: FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WorkoutTemplatesPage(),
              ),
            );
          },
          icon: const Icon(Icons.fitness_center),
          label: const Text('Meine Trainingspläne'),
        ),
      ),
    );
  }
}