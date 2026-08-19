import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import '../services/database_service.dart';
import '../services/app_database.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final AppDatabase _database = DatabaseService.database;

  bool _isLoading = true;

  int _weeklyWorkouts = 0;
  int _weeklySets = 0;
  double _weeklyVolume = 0;
  int _weeklyPrs = 0;

  int _totalWorkouts = 0;
  int _totalSets = 0;
  double _totalVolume = 0;
  int _totalPrs = 0;

  int _currentTrainingStreak = 0;
  int _longestTrainingStreak = 0;
  int _weeklyGoal = 3;

  List<_PersonalRecord> _personalRecords = [];

  List<double> _weeklyVolumes = [];

  Future<int> _calculateWeeklyPrs(
    List<Workout> weeklyWorkouts,
    DateTime startOfWeek,
  ) async {
    // Bisherige Rekorde pro Übung vor dieser Woche
    final previousRecords = <int, double>{};

    final previousWorkouts =
        await (_database.select(_database.workouts)..where(
              (workout) =>
                  workout.completed.equals(true) &
                  workout.date.isSmallerThan(Variable<DateTime>(startOfWeek)),
            ))
            .get();

    for (final workout in previousWorkouts) {
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

        for (final set in sets) {
          final currentRecord =
              previousRecords[workoutExercise.exerciseId] ?? 0;

          if (set.weight > currentRecord) {
            previousRecords[workoutExercise.exerciseId] = set.weight;
          }
        }
      }
    }

    // Höchstes Gewicht pro Übung innerhalb dieser Woche
    final weeklyRecords = <int, double>{};

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

        for (final set in sets) {
          final currentRecord = weeklyRecords[workoutExercise.exerciseId] ?? 0;

          if (set.weight > currentRecord) {
            weeklyRecords[workoutExercise.exerciseId] = set.weight;
          }
        }
      }
    }

    // Zählen, welche Übungen ihren bisherigen Rekord übertroffen haben.
    int prs = 0;

    for (final entry in weeklyRecords.entries) {
      final previousRecord = previousRecords[entry.key] ?? 0;

      if (entry.value > previousRecord) {
        prs++;
      }
    }

    return prs;
  }

  Future<void> _loadTotalProgress() async {
    final workouts = await (_database.select(
      _database.workouts,
    )..where((workout) => workout.completed.equals(true))).get();

    int sets = 0;
    double volume = 0;

    for (final workout in workouts) {
      final workoutExercises = await (_database.select(
        _database.workoutExercises,
      )..where((item) => item.workoutId.equals(workout.id))).get();

      for (final workoutExercise in workoutExercises) {
        final workoutSets =
            await (_database.select(_database.workoutSets)..where(
                  (item) =>
                      item.workoutExerciseId.equals(workoutExercise.id) &
                      item.completed.equals(true),
                ))
                .get();

        for (final set in workoutSets) {
          sets++;
          volume += set.weight * set.repetitions;
        }
      }
    }

    final records = <int, double>{};

    for (final workout in workouts) {
      final workoutExercises = await (_database.select(
        _database.workoutExercises,
      )..where((item) => item.workoutId.equals(workout.id))).get();

      for (final workoutExercise in workoutExercises) {
        final workoutSets =
            await (_database.select(_database.workoutSets)..where(
                  (item) =>
                      item.workoutExerciseId.equals(workoutExercise.id) &
                      item.completed.equals(true),
                ))
                .get();

        for (final set in workoutSets) {
          final current = records[workoutExercise.exerciseId] ?? 0;

          if (set.weight > current) {
            records[workoutExercise.exerciseId] = set.weight;
          }
        }
      }
    }

    if (!mounted) return;

    setState(() {
      _totalWorkouts = workouts.length;
      _totalSets = sets;
      _totalVolume = volume;
      _totalPrs = records.length;
    });
  }

  @override
  void initState() {
    super.initState();

    _loadWeeklyProgress();
    _loadTotalProgress();
    _loadVolumeHistory();
    _loadTrainingStreak();

    _loadPersonalRecords().then((records) {
      if (!mounted) return;

      setState(() {
        _personalRecords = records;
      });
    });
  }

  Future<void> _loadWeeklyProgress() async {
    final now = DateTime.now();

    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final workouts =
        await (_database.select(_database.workouts)..where(
              (workout) =>
                  workout.completed.equals(true) &
                  workout.date.isBiggerOrEqual(
                    Variable<DateTime>(startOfWeek),
                  ) &
                  workout.date.isSmallerThan(Variable<DateTime>(endOfWeek)),
            ))
            .get();

    int sets = 0;
    double volume = 0;

    for (final workout in workouts) {
      final workoutExercises = await (_database.select(
        _database.workoutExercises,
      )..where((item) => item.workoutId.equals(workout.id))).get();

      for (final workoutExercise in workoutExercises) {
        final workoutSets =
            await (_database.select(_database.workoutSets)..where(
                  (item) =>
                      item.workoutExerciseId.equals(workoutExercise.id) &
                      item.completed.equals(true),
                ))
                .get();

        for (final set in workoutSets) {
          sets++;
          volume += set.weight * set.repetitions;
        }
      }
    }

    final prs = await _calculateWeeklyPrs(workouts, startOfWeek);

    if (!mounted) return;

    setState(() {
      _weeklyWorkouts = workouts.length;
      _weeklySets = sets;
      _weeklyVolume = volume;
      _weeklyPrs = prs;
      _isLoading = false;
    });
  }

  Future<List<_PersonalRecord>> _loadPersonalRecords() async {
    final workouts = await (_database.select(
      _database.workouts,
    )..where((workout) => workout.completed.equals(true))).get();

    final records = <int, _PersonalRecord>{};

    for (final workout in workouts) {
      final workoutExercises = await (_database.select(
        _database.workoutExercises,
      )..where((item) => item.workoutId.equals(workout.id))).get();

      for (final workoutExercise in workoutExercises) {
        final exercise =
            await (_database.select(_database.exercises)
                  ..where((item) => item.id.equals(workoutExercise.exerciseId)))
                .getSingle();

        final sets =
            await (_database.select(_database.workoutSets)..where(
                  (item) =>
                      item.workoutExerciseId.equals(workoutExercise.id) &
                      item.completed.equals(true),
                ))
                .get();

        for (final set in sets) {
          final existing = records[workoutExercise.exerciseId];

          if (existing == null || set.weight > existing.weight) {
            records[workoutExercise.exerciseId] = _PersonalRecord(
              exerciseName: exercise.name,
              weight: set.weight,
              date: workout.date,
            );
          }
        }
      }
    }

    final result = records.values.toList();

    result.sort((a, b) => b.weight.compareTo(a.weight));

    return result;
  }

  Future<void> _loadVolumeHistory() async {
    final now = DateTime.now();

    final currentMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    final volumes = <double>[];

    for (int week = 3; week >= 0; week--) {
      final startOfWeek = currentMonday.subtract(Duration(days: week * 7));

      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final workouts =
          await (_database.select(_database.workouts)..where(
                (workout) =>
                    workout.completed.equals(true) &
                    workout.date.isBiggerOrEqual(
                      Variable<DateTime>(startOfWeek),
                    ) &
                    workout.date.isSmallerThan(Variable<DateTime>(endOfWeek)),
              ))
              .get();

      double volume = 0;

      for (final workout in workouts) {
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

          for (final set in sets) {
            volume += set.weight * set.repetitions;
          }
        }
      }

      volumes.add(volume);
    }

    if (!mounted) return;

    setState(() {
      _weeklyVolumes = volumes;
    });
  }

  Widget _buildVolumeChart() {
    if (_weeklyVolumes.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxVolume = _weeklyVolumes.reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📈 Volumenentwicklung',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 220,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int i = 0; i < _weeklyVolumes.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${_weeklyVolumes[i].toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 6),

                            Container(
                              width: 40,
                              height: maxVolume == 0
                                  ? 4
                                  : 150 * (_weeklyVolumes[i] / maxVolume),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'KW ${i + 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadTrainingStreak() async {
    final workouts = await (_database.select(
      _database.workouts,
    )..where((workout) => workout.completed.equals(true))).get();

    if (workouts.isEmpty) {
      if (!mounted) return;

      setState(() {
        _currentTrainingStreak = 0;
        _longestTrainingStreak = 0;
      });

      return;
    }

    final weeks = <DateTime>{};

    for (final workout in workouts) {
      final date = workout.date;

      final monday = DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: date.weekday - 1));

      weeks.add(monday);
    }

    final sortedWeeks = weeks.toList()..sort((a, b) => a.compareTo(b));

    int longestStreak = 1;
    int currentStreak = 1;

    for (int i = 1; i < sortedWeeks.length; i++) {
      final difference = sortedWeeks[i].difference(sortedWeeks[i - 1]).inDays;

      if (difference == 7) {
        currentStreak++;
      } else {
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }

        currentStreak = 1;
      }
    }

    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    final now = DateTime.now();

    final currentMonday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));

    int currentStreakValue = 0;

    if (weeks.contains(currentMonday)) {
      currentStreakValue = 1;

      DateTime checkWeek = currentMonday;

      while (weeks.contains(checkWeek.subtract(const Duration(days: 7)))) {
        checkWeek = checkWeek.subtract(const Duration(days: 7));

        currentStreakValue++;
      }
    }

    if (!mounted) return;

    setState(() {
      _currentTrainingStreak = currentStreakValue;
      _longestTrainingStreak = longestStreak;
    });
  }

  Widget _buildTrainingStreak() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔥 Trainingsserie',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ProgressStat(
                  icon: Icons.local_fire_department,
                  value: '$_currentTrainingStreak',
                  label: 'Aktuelle Serie',
                ),
                _ProgressStat(
                  icon: Icons.emoji_events,
                  value: '$_longestTrainingStreak',
                  label: 'Längste Serie',
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 12),

            const Row(
              children: [
                Icon(Icons.flag_outlined),
                SizedBox(width: 10),
                Text(
                  'Ziel: mindestens 1 Training pro Woche',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyGoal() {
    final progress = _weeklyGoal == 0
        ? 0.0
        : (_weeklyWorkouts / _weeklyGoal).clamp(0.0, 1.0);

    final goalReached = _weeklyWorkouts >= _weeklyGoal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🎯 Wochenziel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_weeklyWorkouts / $_weeklyGoal Trainings',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${(progress * 100).round()} %',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 10),

            LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              borderRadius: BorderRadius.circular(10),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Icon(goalReached ? Icons.check_circle : Icons.flag_outlined),
                const SizedBox(width: 8),
                Text(
                  goalReached
                      ? 'Wochenziel erreicht! 🔥'
                      : 'Noch ${_weeklyGoal - _weeklyWorkouts} Training'
                            '${_weeklyGoal - _weeklyWorkouts == 1 ? '' : 's'}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fortschritt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Dein Fortschritt',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Diese Woche',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ProgressStat(
                        icon: Icons.fitness_center,
                        value: '$_weeklyWorkouts',
                        label: 'Trainings',
                      ),
                      _ProgressStat(
                        icon: Icons.check_circle,
                        value: '$_weeklySets',
                        label: 'Sätze',
                      ),
                      _ProgressStat(
                        icon: Icons.scale,
                        value: '${_weeklyVolume.toStringAsFixed(0)} kg',
                        label: 'Volumen',
                      ),
                      _ProgressStat(
                        icon: Icons.emoji_events,
                        value: '$_weeklyPrs',
                        label: 'PRs',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          _buildVolumeChart(),

          const SizedBox(height: 20),

          _buildTrainingStreak(),

          const SizedBox(height: 20),

          _buildWeeklyGoal(),

          const SizedBox(height: 20),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gesamt',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ProgressStat(
                        icon: Icons.fitness_center,
                        value: '$_totalWorkouts',
                        label: 'Trainings',
                      ),
                      _ProgressStat(
                        icon: Icons.check_circle,
                        value: '$_totalSets',
                        label: 'Sätze',
                      ),
                      _ProgressStat(
                        icon: Icons.scale,
                        value: '${_totalVolume.toStringAsFixed(0)} kg',
                        label: 'Volumen',
                      ),
                      _ProgressStat(
                        icon: Icons.emoji_events,
                        value: '$_totalPrs',
                        label: 'Rekorde',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🏆 Persönliche Rekorde',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  if (_personalRecords.isEmpty)
                    const Text(
                      'Noch keine Rekorde vorhanden.',
                      style: TextStyle(color: Colors.grey),
                    )
                  else
                    Column(
                      children: [
                        for (final record in _personalRecords)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.emoji_events),
                            title: Text(
                              record.exerciseName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${record.date.day.toString().padLeft(2, '0')}.'
                              '${record.date.month.toString().padLeft(2, '0')}.'
                              '${record.date.year}',
                            ),
                            trailing: Text(
                              '${record.weight.toStringAsFixed(1)} kg',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalRecord {
  final String exerciseName;
  final double weight;
  final DateTime date;

  const _PersonalRecord({
    required this.exerciseName,
    required this.weight,
    required this.date,
  });
}

class _ProgressStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _ProgressStat({
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
