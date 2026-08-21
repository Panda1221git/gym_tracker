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

  Future<_WorkoutStatistics> _loadStatistics(List<Workout> workouts) async {
    double totalVolume = 0;
    double maxWeight = 0;

    final workoutVolumes = <int, double>{};
    final personalRecords = <String, _PersonalRecord>{};

    for (final workout in workouts) {
      double workoutVolume = 0;

      final workoutExercises = await (_database.select(
        _database.workoutExercises,
      )..where((item) => item.workoutId.equals(workout.id))).get();

      for (final workoutExercise in workoutExercises) {
        final sets =
            await (_database.select(_database.workoutSets)..where(
                  (item) => item.workoutExerciseId.equals(workoutExercise.id),
                ))
                .get();

        final exercise =
            await (_database.select(_database.exercises)
                  ..where((item) => item.id.equals(workoutExercise.exerciseId)))
                .getSingle();

        for (final set in sets) {
          final volume = set.weight * set.repetitions;

          workoutVolume += volume;
          totalVolume += volume;

          if (set.weight > maxWeight) {
            maxWeight = set.weight;
          }

          final currentRecord = personalRecords[exercise.name]?.weight ?? 0.0;

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
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fortschritt',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: StreamBuilder<List<Workout>>(
        stream:
            (_database.select(_database.workouts)
                  ..where((workout) => workout.completed.equals(true))
                  ..orderBy([
                    (workout) => OrderingTerm(
                      expression: workout.date,
                      mode: OrderingMode.desc,
                    ),
                  ]))
                .watch(),

        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Fehler: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final workouts = snapshot.data ?? [];

          if (workouts.isEmpty) {
            return _EmptyHistory(accent: accent);
          }

          return FutureBuilder<_WorkoutStatistics>(
            future: _loadStatistics(workouts),
            builder: (context, statisticsSnapshot) {
              if (statisticsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (statisticsSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Fehler: ${statisticsSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final statistics = statisticsSnapshot.data!;

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                children: [
                  // ========================================================
                  // Header
                  // ========================================================
                  const Text(
                    'DEIN FORTSCHRITT',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Deine bisherigen Trainings auf einen Blick.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),

                  const SizedBox(height: 20),

                  // ========================================================
                  // Hauptstatistiken
                  // ========================================================
                  Row(
                    children: [
                      Expanded(
                        child: _StatisticCard(
                          icon: Icons.fitness_center,
                          title: 'Trainings',
                          value: '${statistics.workoutCount}',
                          accent: accent,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _StatisticCard(
                          icon: Icons.monitor_weight_outlined,
                          title: 'Volumen',
                          value: '${_formatNumber(statistics.totalVolume)} kg',
                          accent: accent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _StatisticCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'Höchstes Gewicht',
                    value: '${_formatNumber(statistics.maxWeight)} kg',
                    accent: accent,
                    large: true,
                  ),

                  const SizedBox(height: 28),

                  // ========================================================
                  // Trainingskalender
                  // ========================================================
                  const _SectionTitle(title: 'TRAININGSÜBERSICHT'),

                  const SizedBox(height: 12),

                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TrainingCalendarPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            _IconBox(
                              icon: Icons.calendar_month,
                              accent: accent,
                            ),

                            const SizedBox(width: 14),

                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Trainingskalender',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Trainingstage und Rest Days ansehen',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ========================================================
                  // Persönliche Bestleistungen
                  // ========================================================
                  const _SectionTitle(title: 'PERSÖNLICHE BESTLEISTUNGEN'),

                  const SizedBox(height: 12),

                  if (statistics.personalRecords.isEmpty)
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          'Noch keine Bestleistungen vorhanden.',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ),
                    )
                  else
                    ...statistics.personalRecords.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            final exercise =
                                await (_database.select(_database.exercises)
                                      ..where(
                                        (item) => item.name.equals(entry.key),
                                      ))
                                    .getSingleOrNull();

                            if (!mounted || exercise == null) {
                              return;
                            }

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
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                _IconBox(
                                  icon: Icons.emoji_events,
                                  accent: accent,
                                ),

                                const SizedBox(width: 14),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      Text(
                                        'Persönliche Bestleistung',
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${_formatNumber(entry.value.weight)} kg',
                                      style: TextStyle(
                                        color: accent,
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 3),

                                    Text(
                                      '${entry.value.repetitions} Wdh.',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(width: 8),

                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 18),

                  // ========================================================
                  // Letzte Trainings
                  // ========================================================
                  const _SectionTitle(title: 'LETZTE TRAININGS'),

                  const SizedBox(height: 12),

                  for (final workout in workouts)
                    Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  WorkoutDetailPage(workout: workout),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              _IconBox(
                                icon: Icons.fitness_center,
                                accent: accent,
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      workout.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 5),

                                    Text(
                                      _formatDate(workout.date),
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${_formatNumber(statistics.workoutVolumes[workout.id] ?? 0)} kg',
                                    style: TextStyle(
                                      color: accent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),

                                  const SizedBox(height: 3),

                                  Text(
                                    'Volumen',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(width: 8),

                              Icon(
                                Icons.chevron_right,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _IconBox({required this.icon, required this.accent});

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

class _EmptyHistory extends StatelessWidget {
  final Color accent;

  const _EmptyHistory({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fitness_center, size: 42, color: accent),
            ),

            const SizedBox(height: 22),

            const Text(
              'Noch keine Trainings',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Absolviere dein erstes Training, '
              'um hier deinen Fortschritt zu sehen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalRecord {
  final double weight;
  final int repetitions;

  const _PersonalRecord({required this.weight, required this.repetitions});
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
  final Color accent;
  final bool large;

  const _StatisticCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.accent,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _IconBox(icon: icon, accent: accent),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    value,
                    style: TextStyle(
                      color: large ? accent : Colors.white,
                      fontSize: large ? 25 : 21,
                      fontWeight: FontWeight.bold,
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
}
