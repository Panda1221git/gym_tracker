import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';

import '../services/app_database.dart';
import '../services/database_service.dart';

class ExerciseProgressPage extends StatefulWidget {
  final int exerciseId;
  final String exerciseName;

  const ExerciseProgressPage({
    super.key,
    required this.exerciseId,
    required this.exerciseName,
  });

  @override
  State<ExerciseProgressPage> createState() =>
      _ExerciseProgressPageState();
}

class _ExerciseProgressPageState
    extends State<ExerciseProgressPage> {
  final AppDatabase _database = DatabaseService.database;

  bool _isLoading = true;
  List<_ProgressEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final workouts = await (_database.select(_database.workouts)
          ..where(
            (workout) => workout.completed.equals(true),
          )
          ..orderBy([
            (workout) => OrderingTerm(
                  expression: workout.date,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();

    final entries = <_ProgressEntry>[];

    for (final workout in workouts) {
      final workoutExercises =
          await (_database.select(_database.workoutExercises)
                ..where(
                  (item) =>
                      item.workoutId.equals(workout.id) &
                      item.exerciseId.equals(widget.exerciseId),
                ))
              .get();

      if (workoutExercises.isEmpty) {
        continue;
      }

      double bestWeight = 0;
      int bestRepetitions = 0;

      for (final workoutExercise in workoutExercises) {
        final sets = await (_database.select(_database.workoutSets)
              ..where(
                (item) =>
                    item.workoutExerciseId.equals(
                  workoutExercise.id,
                ),
              ))
            .get();

        for (final set in sets) {
          if (set.weight > bestWeight) {
            bestWeight = set.weight;
            bestRepetitions = set.repetitions;
          }
        }
      }

      if (bestWeight > 0) {
        entries.add(
          _ProgressEntry(
            date: workout.date,
            weight: bestWeight,
            repetitions: bestRepetitions,
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _entries = entries;
      _isLoading = false;
    });
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
        title: Text(widget.exerciseName),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _entries.isEmpty
              ? const Center(
                  child: Text(
                    'Noch keine Fortschrittsdaten vorhanden.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '📈 ${widget.exerciseName}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall,
                    ),

                    const SizedBox(height: 20),

                    // =========================
                    // GEWICHTSVERLAUF
                    // =========================

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gewichtsverlauf',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 20),

                            SizedBox(
                              height: 280,
                              child: LineChart(
                                LineChartData(
                                  minX: 0,
                                  maxX: _entries.length > 1
                                      ? (_entries.length - 1)
                                          .toDouble()
                                      : 1,

                                  minY: _getMinWeight(),

                                  maxY: _getMaxWeight(),

                                  gridData:
                                      const FlGridData(
                                    show: true,
                                  ),

                                  titlesData: FlTitlesData(
                                    topTitles:
                                        const AxisTitles(
                                      sideTitles:
                                          SideTitles(
                                        showTitles: false,
                                      ),
                                    ),
                                    rightTitles:
                                        const AxisTitles(
                                      sideTitles:
                                          SideTitles(
                                        showTitles: false,
                                      ),
                                    ),
                                    leftTitles:
                                        const AxisTitles(
                                      sideTitles:
                                          SideTitles(
                                        showTitles: true,
                                        reservedSize: 45,
                                      ),
                                    ),
                                    bottomTitles:
                                        AxisTitles(
                                      sideTitles:
                                          SideTitles(
                                        showTitles: true,
                                        interval: 1,
                                        getTitlesWidget:
                                            (
                                          value,
                                          meta,
                                        ) {
                                          final index =
                                              value.toInt();

                                          if (index < 0 ||
                                              index >=
                                                  _entries
                                                      .length) {
                                            return const SizedBox();
                                          }

                                          final date =
                                              _entries[index]
                                                  .date;

                                          return Padding(
                                            padding:
                                                const EdgeInsets
                                                    .only(
                                              top: 8,
                                            ),
                                            child: Text(
                                              '${date.day}.${date.month}.',
                                              style:
                                                  const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: [
                                        for (int i = 0;
                                            i <
                                                _entries
                                                    .length;
                                            i++)
                                          FlSpot(
                                            i.toDouble(),
                                            _entries[i]
                                                .weight,
                                          ),
                                      ],
                                      isCurved: true,
                                      barWidth: 3,
                                      dotData:
                                          const FlDotData(
                                        show: true,
                                      ),
                                      belowBarData:
                                          BarAreaData(
                                        show: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =========================
                    // TRAININGSVERLAUF
                    // =========================

                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Trainingsverlauf',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 16),

                            for (final entry
                                in _entries.reversed)
                              ListTile(
                                contentPadding:
                                    EdgeInsets.zero,
                                leading:
                                    const CircleAvatar(
                                  child: Icon(
                                    Icons.fitness_center,
                                  ),
                                ),
                                title: Text(
                                  '${_formatNumber(entry.weight)} kg × '
                                  '${entry.repetitions} Wdh.',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatDate(entry.date),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  double _getMinWeight() {
    double minWeight = _entries.first.weight;

    for (final entry in _entries) {
      if (entry.weight < minWeight) {
        minWeight = entry.weight;
      }
    }

    return (minWeight - 5).clamp(0, double.infinity);
  }

  double _getMaxWeight() {
    double maxWeight = _entries.first.weight;

    for (final entry in _entries) {
      if (entry.weight > maxWeight) {
        maxWeight = entry.weight;
      }
    }

    return maxWeight + 5;
  }
}

class _ProgressEntry {
  final DateTime date;
  final double weight;
  final int repetitions;

  const _ProgressEntry({
    required this.date,
    required this.weight,
    required this.repetitions,
  });
}