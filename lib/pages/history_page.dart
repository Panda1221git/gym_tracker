import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../services/app_database.dart';
import '../services/database_service.dart';
import 'workout_detail_page.dart';
import 'exercise_progress_page.dart';
import 'training_calender_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final AppDatabase _database = DatabaseService.database;

  Future<_WorkoutStatistics> _loadStatistics(
    List<Workout> workouts,
  ) async {
    double totalVolume = 0;
    double maxWeight = 0;

    final workoutVolumes = <int, double>{};
    final personalRecords = <String, _PersonalRecord>{};

    for (final workout in workouts) {
      double workoutVolume = 0;

      final workoutExercises = await (_database
            .select(_database.workoutExercises)
            ..where(
              (item) => item.workoutId.equals(workout.id),
            ))
          .get();

      for (final workoutExercise in workoutExercises) {
        final sets = await (_database.select(_database.workoutSets)
              ..where(
                (item) =>
                    item.workoutExerciseId.equals(workoutExercise.id),
              ))
            .get();

        final exercise = await (_database.select(_database.exercises)
              ..where(
                (item) => item.id.equals(workoutExercise.exerciseId),
              ))
            .getSingle();

        for (final set in sets) {
          final volume = set.weight * set.repetitions;

          workoutVolume += volume;
          totalVolume += volume;

          if (set.weight > maxWeight) {
            maxWeight = set.weight;
          }

          final currentRecord =
              personalRecords[exercise.name]?.weight ?? 0.0;

          if (set.weight > currentRecord) {
            personalRecords[exercise.name] = _PersonalRecord(
              weight: set.weight,
              repetitions: set.repetitions,
            );
          }
        }
      }

      workoutVolumes[workout.id] = workoutVolume;
    }

    return _WorkoutStatistics(
      workoutCount: workouts.length,
      totalVolume: totalVolume,
      maxWeight: maxWeight,
      workoutVolumes: workoutVolumes,
      personalRecords: personalRecords,
    );
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fortschritt'),
      ),
      body: StreamBuilder<List<Workout>>(
        stream: (_database.select(_database.workouts)
              ..where(
                (workout) => workout.completed.equals(true),
              )
              ..orderBy([
                (workout) => OrderingTerm(
                      expression: workout.date,
                      mode: OrderingMode.desc,
                    ),
              ]))
            .watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Fehler: ${snapshot.error}',
              ),
            );
          }

          final workouts = snapshot.data ?? [];

          if (workouts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fitness_center,
                    size: 64,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Noch keine Trainings vorhanden',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Absolviere dein erstes Training!',
                  ),
                ],
              ),
            );
          }

          return FutureBuilder<_WorkoutStatistics>(
            future: _loadStatistics(workouts),
            builder: (context, statisticsSnapshot) {
              if (statisticsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (statisticsSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Fehler: ${statisticsSnapshot.error}',
                  ),
                );
              }

              final statistics = statisticsSnapshot.data!;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatisticCard(
                          icon: Icons.fitness_center,
                          title: 'Trainings',
                          value: '${statistics.workoutCount}',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatisticCard(
                          icon: Icons.monitor_weight,
                          title: 'Volumen',
                          value:
                              '${_formatNumber(statistics.totalVolume)} kg',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _StatisticCard(
                    icon: Icons.emoji_events,
                    title: 'Höchstes Gewicht',
                    value:
                        '${_formatNumber(statistics.maxWeight)} kg',
                  ),

                  Card(
  child: ListTile(
    leading: const CircleAvatar(
      child: Icon(Icons.calendar_month),
    ),
    title: const Text(
      'Trainingskalender',
      style: TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    subtitle: const Text(
      'Trainingstage und Rest Days ansehen',
    ),
    trailing: const Icon(
      Icons.chevron_right,
    ),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const TrainingCalendarPage(),
        ),
      );
    },
  ),
),

                  const SizedBox(height: 24),

                  Text(
                    '🏆 Persönliche Bestleistungen',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),

                  const SizedBox(height: 12),

                  if (statistics.personalRecords.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Noch keine Bestleistungen vorhanden.',
                        ),
                      ),
                    )
                  else
                    ...statistics.personalRecords.entries.map(
                      (entry) {
                        return Card(
  margin: const EdgeInsets.only(bottom: 8),
  child: ListTile(
    leading: const CircleAvatar(
      child: Icon(Icons.emoji_events),
    ),
    title: Text(
      entry.key,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${_formatNumber(entry.value.weight)} kg × '
          '${entry.value.repetitions} Wdh.',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.chevron_right),
      ],
    ),
    onTap: () async {
      final exercise = await (_database.select(_database.exercises)
            ..where(
              (item) => item.name.equals(entry.key),
            ))
          .getSingleOrNull();

      if (!mounted || exercise == null) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ExerciseProgressPage(
            exerciseId: exercise.id,
            exerciseName: exercise.name,
          ),
        ),
      );
    },
  ),
);
                      },
                    ),

                  const SizedBox(height: 24),

                  Text(
                    'Letzte Trainings',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),

                  const SizedBox(height: 12),

                  for (final workout in workouts)
                    Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.fitness_center),
                        ),
                        title: Text(
                          workout.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${_formatDate(workout.date)}\n'
                          'Volumen: '
                          '${_formatNumber(
                            statistics.workoutVolumes[workout.id] ?? 0,
                          )} kg',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(
                          Icons.chevron_right,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WorkoutDetailPage(
                                workout: workout,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PersonalRecord {
  final double weight;
  final int repetitions;

  const _PersonalRecord({
    required this.weight,
    required this.repetitions,
  });
}

class _WorkoutStatistics {
  final int workoutCount;
  final double totalVolume;
  final double maxWeight;
  final Map<int, double> workoutVolumes;
  final Map<String, _PersonalRecord> personalRecords;

  const _WorkoutStatistics({
    required this.workoutCount,
    required this.totalVolume,
    required this.maxWeight,
    required this.workoutVolumes,
    required this.personalRecords,
  });
}

class _StatisticCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatisticCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}