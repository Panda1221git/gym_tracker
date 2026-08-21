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

    if (!mounted) return;

    setState(() {
      _nextWorkout = templates.isNotEmpty ? templates.first : null;
      _lastWorkout = workouts.isNotEmpty ? workouts.first : null;
      _weeklyWorkouts = weeklyWorkouts.length;
      _weeklySets = weeklySets;

      // Trainingsdauer wird momentan noch nicht gespeichert.
      _weeklyMinutes = 0;

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

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return 'Guten Morgen 👋';
    }

    if (hour < 18) {
      return 'Guten Tag 👋';
    }

    return 'Guten Abend 👋';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'GymTracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _loadHomeData,
            tooltip: 'Aktualisieren',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ============================================================
              // Begrüßung
              // ============================================================
              Text(
                _getGreeting(),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Bereit für dein nächstes Training?',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
              ),

              const SizedBox(height: 24),

              // ============================================================
              // Nächstes Training
              // ============================================================
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: accent,
                              size: 26,
                            ),
                          ),

                          const SizedBox(width: 14),

                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DEIN NÄCHSTES TRAINING',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Bereit für die nächste Einheit?',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      if (_nextWorkout == null)
                        Text(
                          'Noch keinen Trainingsplan erstellt.',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 15,
                          ),
                        )
                      else ...[
                        Text(
                          _nextWorkout!.name,
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Dein nächstes Training wartet auf dich.',
                          style: TextStyle(color: Colors.grey.shade400),
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

              const SizedBox(height: 28),

              // ============================================================
              // Wochenstatistik
              // ============================================================
              const Text(
                'DEINE WOCHE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.fitness_center,
                      value: '$_weeklyWorkouts',
                      label: 'Trainings',
                      accent: accent,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle_outline,
                      value: '$_weeklySets',
                      label: 'Sätze',
                      accent: accent,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: _StatCard(
                      icon: Icons.timer_outlined,
                      value: '$_weeklyMinutes',
                      label: 'Minuten',
                      accent: accent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // ============================================================
              // Letztes Training
              // ============================================================
              const Text(
                'LETZTES TRAINING',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              Card(
                margin: EdgeInsets.zero,
                child: _lastWorkout == null
                    ? Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            _HistoryIcon(accent: accent, icon: Icons.history),

                            const SizedBox(width: 14),

                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Noch kein Training',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Starte dein erstes Training!',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            _HistoryIcon(
                              accent: accent,
                              icon: Icons.fitness_center,
                            ),

                            const SizedBox(width: 14),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _lastWorkout!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    _formatWorkoutDate(_lastWorkout!.date),
                                    style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
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
  final Color accent;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
        child: Column(
          children: [
            Icon(icon, size: 25, color: accent),

            const SizedBox(height: 9),

            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryIcon extends StatelessWidget {
  final Color accent;
  final IconData icon;

  const _HistoryIcon({required this.accent, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: accent, size: 24),
    );
  }
}
