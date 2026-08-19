import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../services/app_database.dart';
import '../services/database_service.dart';

class WorkoutDetailPage extends StatefulWidget {
  final Workout workout;

  const WorkoutDetailPage({
    super.key,
    required this.workout,
  });

  @override
  State<WorkoutDetailPage> createState() => _WorkoutDetailPageState();
}

class _WorkoutDetailPageState extends State<WorkoutDetailPage> {
  final AppDatabase _database = DatabaseService.database;

  Future<List<_ExerciseDetail>> _loadDetails() async {
    final workoutExercises = await (_database
          .select(_database.workoutExercises)
          ..where(
            (item) => item.workoutId.equals(widget.workout.id),
          )
          ..orderBy([
            (item) => OrderingTerm(
                  expression: item.orderIndex,
                ),
          ]))
        .get();

    final details = <_ExerciseDetail>[];

    for (final workoutExercise in workoutExercises) {
      final exercise = await (_database.select(_database.exercises)
            ..where(
              (item) => item.id.equals(workoutExercise.exerciseId),
            ))
          .getSingle();

      final sets = await (_database.select(_database.workoutSets)
            ..where(
              (item) =>
                  item.workoutExerciseId.equals(workoutExercise.id),
            )
            ..orderBy([
              (item) => OrderingTerm(
                    expression: item.setNumber,
                  ),
            ]))
          .get();

      details.add(
        _ExerciseDetail(
          exercise: exercise,
          sets: sets,
        ),
      );
    }

    return details;
  }

  @override
  Widget build(BuildContext context) {
    final date = widget.workout.date;

    final formattedDate =
        '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workout.name),
      ),
      body: FutureBuilder<List<_ExerciseDetail>>(
        future: _loadDetails(),
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

          final details = snapshot.data ?? [];

          if (details.isEmpty) {
            return const Center(
              child: Text(
                'Für dieses Training wurden keine Übungen gespeichert.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                formattedDate,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              for (final detail in details)
                Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detail.exercise.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (detail.sets.isEmpty)
                          const Text(
                            'Keine Sätze gespeichert.',
                            style: TextStyle(
                              color: Colors.grey,
                            ),
                          )
                        else
                          for (final set in detail.sets)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                child: Text(
                                  '${set.setNumber}',
                                ),
                              ),
                              title: Text(
                                '${set.weight} kg × '
                                '${set.repetitions} Wdh.',
                              ),
                              trailing: set.completed
                                  ? const Icon(
                                      Icons.check_circle,
                                    )
                                  : const Icon(
                                      Icons.circle_outlined,
                                    ),
                            ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExerciseDetail {
  final Exercise exercise;
  final List<WorkoutSet> sets;

  const _ExerciseDetail({
    required this.exercise,
    required this.sets,
  });
}