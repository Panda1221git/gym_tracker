import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../services/database_service.dart';
import '../services/app_database.dart';
import 'active_workout_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppDatabase _database = DatabaseService.database;

  bool _isLoading = true;

  WorkoutTemplate? _nextWorkout;
  Workout? _lastWorkout;

  int _weeklyWorkouts = 0;
  int _weeklySets = 0;
  int _weeklyMinutes = 0;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    final user = await DatabaseService.getOrCreateDefaultUser();

    final templates =
        await (_database.select(_database.workoutTemplates)
              ..where((template) => template.userId.equals(user.id))
              ..orderBy([
                (template) => OrderingTerm(expression: template.orderIndex),
              ]))
            .get();

    final workouts =
        await (_database.select(_database.workouts)
              ..where(
                (workout) =>
                    workout.userId.equals(user.id) &
                    workout.completed.equals(true),
              )
              ..orderBy([
                (workout) => OrderingTerm(
                  expression: workout.date,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    final now = DateTime.now();

    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final weeklyWorkouts = workouts.where((workout) {
      return !workout.date.isBefore(startOfWeek) &&
          workout.date.isBefore(endOfWeek);
    }).toList();

    int weeklySets = 0;
    int weeklyMinutes = 0;

    for (final workout in weeklyWorkouts) {
      final workoutExercises = await (_database.select(
        _database.workoutExercises,
      )..where((item) => item.workoutId.equals(workout.id))).get();

      for (final workoutExercise in workoutExercises) {
        final sets =
            await (_database.select(_database.workoutSets)..where(
                  (item) =>
                      item.workoutExerciseId.equals(workoutExercise.id) &
                      item.completed.equals(true),
                ))
                .get();

        weeklySets += sets.length;
      }
    }

    // Trainingsdauer aus Start- und Endzeit ist aktuell nicht
    // in der Datenbank gespeichert.
    // Deshalb bleiben die Minuten vorerst bei 0.
    weeklyMinutes = 0;

    if (!mounted) return;

    setState(() {
      _nextWorkout = templates.isNotEmpty ? templates.first : null;
      _lastWorkout = workouts.isNotEmpty ? workouts.first : null;
      _weeklyWorkouts = weeklyWorkouts.length;
      _weeklySets = weeklySets;
      _weeklyMinutes = weeklyMinutes;
      _isLoading = false;
    });
  }

  Future<void> _startWorkout() async {
    final workout = _nextWorkout;

    if (workout == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Du hast noch keinen Trainingsplan erstellt.'),
        ),
      );

      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutPage(
          templateId: workout.id,
          workoutName: workout.name,
        ),
      ),
    );

    if (!mounted) return;

    await _loadHomeData();
  }

  String _formatWorkoutDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GymTracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Heute',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 6),

              Text(
                'Bereit für dein nächstes Training? 💪',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),

              const SizedBox(height: 24),

              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.fitness_center, size: 40),

                      const SizedBox(height: 16),

                      const Text(
                        'Dein nächstes Training',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      if (_nextWorkout == null)
                        Text(
                          'Noch keinen Trainingsplan erstellt.',
                          style: TextStyle(color: Colors.grey.shade600),
                        )
                      else ...[
                        Text(
                          _nextWorkout!.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Bereit für deine nächste Einheit?',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],

                      const SizedBox(height: 20),

                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _nextWorkout == null
                              ? null
                              : _startWorkout,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Training starten'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Deine Woche',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.fitness_center,
                      value: '$_weeklyWorkouts',
                      label: 'Trainings',
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _StatCard(
                      icon: Icons.repeat,
                      value: '$_weeklySets',
                      label: 'Sätze',
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer,
                      value: '$_weeklyMinutes',
                      label: 'Minuten',
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              const Text(
                'Letztes Training',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Card(
                child: _lastWorkout == null
                    ? const ListTile(
                        leading: CircleAvatar(child: Icon(Icons.history)),
                        title: Text(
                          'Noch kein Training',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('Starte dein erstes Training!'),
                      )
                    : ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.history)),
                        title: Text(
                          _lastWorkout!.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(_formatWorkoutDate(_lastWorkout!.date)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, size: 28),

            const SizedBox(height: 8),

            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
