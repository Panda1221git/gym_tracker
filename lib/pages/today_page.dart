import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../services/database_service.dart';
import '../services/app_database.dart';
import 'active_workout_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final AppDatabase _database = DatabaseService.database;

  bool _isLoading = true;

  WorkoutTemplate? _todayTemplate;

  int _weeklyWorkouts = 0;
  int _weeklySets = 0;

  int _currentTrainingStreak = 0;

  Workout? _lastWorkout;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    final user = await DatabaseService.getOrCreateDefaultUser();

    final templates =
        await (_database.select(_database.workoutTemplates)
              ..where((template) => template.userId.equals(user.id))
              ..orderBy([
                (template) => OrderingTerm(expression: template.orderIndex),
              ]))
            .get();

            debugPrint('TODAY: User ID = ${user.id}');
debugPrint('TODAY: Templates gefunden = ${templates.length}');

for (final template in templates) {
  debugPrint(
    'TODAY: Template ${template.id} = ${template.name}',
  );
}

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

    final weeks = <DateTime>{};

    for (final workout in workouts) {
      final monday = DateTime(
        workout.date.year,
        workout.date.month,
        workout.date.day,
      ).subtract(Duration(days: workout.date.weekday - 1));

      weeks.add(monday);
    }

    int streak = 0;
    DateTime currentWeek = startOfWeek;

    while (weeks.contains(currentWeek)) {
      streak++;

      currentWeek = currentWeek.subtract(const Duration(days: 7));
    }

    if (!mounted) return;

    setState(() {
      _todayTemplate = templates.isNotEmpty ? templates.first : null;
      _weeklyWorkouts = weeklyWorkouts.length;
      _weeklySets = weeklySets;
      _currentTrainingStreak = streak;
      _lastWorkout = workouts.isNotEmpty ? workouts.first : null;
      _isLoading = false;
    });
  }

  Future<void> _startWorkout() async {
    final template = _todayTemplate;

    if (template == null) {
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
          templateId: template.id,
          workoutName: template.name,
        ),
      ),
    );

    if (!mounted) return;

    await _loadTodayData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Heute')),
      body: RefreshIndicator(
        onRefresh: _loadTodayData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Guten Tag 👋',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            Text(
              'Bereit für dein Training?',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),

            const SizedBox(height: 24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🏋️ Heutiges Training',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (_todayTemplate == null)
                      const Text(
                        'Noch kein Trainingsplan vorhanden.',
                        style: TextStyle(color: Colors.grey),
                      )
                    else ...[
                      Text(
                        _todayTemplate!.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Dein nächstes Training',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _todayTemplate == null
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

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📊 Diese Woche',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _TodayStat(
                          icon: Icons.fitness_center,
                          value: '$_weeklyWorkouts',
                          label: 'Trainings',
                        ),
                        _TodayStat(
                          icon: Icons.check_circle,
                          value: '$_weeklySets',
                          label: 'Sätze',
                        ),
                        _TodayStat(
                          icon: Icons.local_fire_department,
                          value: '$_currentTrainingStreak',
                          label: 'Wochenserie',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 30),

                    const SizedBox(width: 14),

                    Expanded(
                      child: _lastWorkout == null
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Letztes Training',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Noch kein Training absolviert.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Letztes Training',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _lastWorkout!.name,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_lastWorkout!.date.day.toString().padLeft(2, '0')}.'
                                  '${_lastWorkout!.date.month.toString().padLeft(2, '0')}.'
                                  '${_lastWorkout!.date.year}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),

                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _TodayStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
