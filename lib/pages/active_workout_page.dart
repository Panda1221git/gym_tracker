import 'dart:async';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_database.dart';
import '../services/database_service.dart';

class ActiveWorkoutPage extends StatefulWidget {
  final int templateId;
  final String workoutName;

  const ActiveWorkoutPage({
    super.key,
    required this.templateId,
    required this.workoutName,
  });

  @override
  State<ActiveWorkoutPage> createState() => _ActiveWorkoutPageState();
}

class _ActiveWorkoutPageState extends State<ActiveWorkoutPage> {
  final AppDatabase _database = DatabaseService.database;

  bool _isLoading = true;
  int? _workoutId;

  List<_WorkoutExerciseData> _exercises = [];

  int _completedSets = 0;

  DateTime? _workoutStartTime;

  // Satzpausen-Timer
  Timer? _restTimer;

  Duration _restDuration = const Duration(minutes: 3);
  Duration _remainingRest = Duration.zero;

  DateTime? _restEndTime;

  bool _restTimerRunning = false;

  @override
  void initState() {
    super.initState();
    _loadRestTimerSetting();
    _startWorkout();
  }

  Future<void> _startWorkout() async {
    final user = await DatabaseService.getOrCreateDefaultUser();

    final workoutStartTime = DateTime.now();

    final workoutId = await _database
        .into(_database.workouts)
        .insert(
          WorkoutsCompanion.insert(
            userId: user.id,
            templateId: widget.templateId,
            name: widget.workoutName,
            date: DateTime.now(),
          ),
        );

    final query = _database.select(_database.templateExercises).join([
      innerJoin(
        _database.exercises,
        _database.exercises.id.equalsExp(
          _database.templateExercises.exerciseId,
        ),
      ),
    ]);

    query.where(
      _database.templateExercises.templateId.equals(widget.templateId),
    );

    query.orderBy([
      OrderingTerm(expression: _database.templateExercises.orderIndex),
    ]);

    final results = await query.get();

    final exercises = results.map((result) {
      final templateExercise = result.readTable(_database.templateExercises);

      final exercise = result.readTable(_database.exercises);

      return _WorkoutExerciseData(
        templateExercise: templateExercise,
        exercise: exercise,
      );
    }).toList();

    if (!mounted) return;

    setState(() {
      _workoutId = workoutId;
      _workoutStartTime = workoutStartTime;
      _exercises = exercises;
      _isLoading = false;
    });
  }

  Future<void> _loadRestTimerSetting() async {
    final prefs = await SharedPreferences.getInstance();

    final seconds = prefs.getInt('rest_timer_seconds') ?? 180;

    if (!mounted) return;

    setState(() {
      _restDuration = Duration(seconds: seconds);
    });
  }

  Future<void> _saveRestTimerSetting(Duration duration) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setInt('rest_timer_seconds', duration.inSeconds);

    if (!mounted) return;

    setState(() {
      _restDuration = duration;
    });
  }

  void _startRestTimer() {
    _restTimer?.cancel();

    _restEndTime = DateTime.now().add(_restDuration);

    setState(() {
      _remainingRest = _restDuration;
      _restTimerRunning = true;
    });

    _restTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRestTimer(),
    );
  }

  void _updateRestTimer() {
    if (_restEndTime == null) return;

    final remaining = _restEndTime!.difference(DateTime.now());

    if (remaining <= Duration.zero) {
      _restTimer?.cancel();

      if (!mounted) return;

      setState(() {
        _remainingRest = Duration.zero;
        _restTimerRunning = false;
        _restEndTime = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Pause vorbei – nächster Satz!'),
          duration: Duration(seconds: 3),
        ),
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      _remainingRest = remaining;
    });
  }

  void _pauseRestTimer() {
    _restTimer?.cancel();

    setState(() {
      _restTimerRunning = false;
    });
  }

  void _resumeRestTimer() {
    if (_remainingRest <= Duration.zero) {
      _startRestTimer();
      return;
    }

    _restEndTime = DateTime.now().add(_remainingRest);

    setState(() {
      _restTimerRunning = true;
    });

    _restTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateRestTimer(),
    );
  }

  void _skipRestTimer() {
    _restTimer?.cancel();

    setState(() {
      _remainingRest = Duration.zero;
      _restTimerRunning = false;
      _restEndTime = null;
    });
  }

  String _formatRestTime(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');

    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Future<void> _showRestTimerSettings() async {
    const options = [
      Duration(minutes: 1),
      Duration(minutes: 1, seconds: 30),
      Duration(minutes: 2),
      Duration(minutes: 2, seconds: 30),
      Duration(minutes: 3),
    ];

    final selected = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Satzpause einstellen',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              for (final duration in options)
                ListTile(
                  leading: const Icon(Icons.timer),
                  title: Text(_formatRestTime(duration)),
                  trailing: duration == _restDuration
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () {
                    Navigator.pop(context, duration);
                  },
                ),
            ],
          ),
        );
      },
    );

    if (selected == null || !mounted) return;

    await _saveRestTimerSetting(selected);
  }

  Future<void> _loadCompletedSets() async {
    if (_workoutId == null) return;

    final workoutExercises = await (_database.select(
      _database.workoutExercises,
    )..where((item) => item.workoutId.equals(_workoutId!))).get();

    int completed = 0;

    for (final workoutExercise in workoutExercises) {
      final sets =
          await (_database.select(_database.workoutSets)..where(
                (item) =>
                    item.workoutExerciseId.equals(workoutExercise.id) &
                    item.completed.equals(true),
              ))
              .get();

      completed += sets.length;
    }

    if (!mounted) return;

    setState(() {
      _completedSets = completed;
    });
  }

  Future<void> _saveSet({
    required int workoutExerciseId,
    required int setNumber,
    required double weight,
    required int repetitions,
  }) async {
    await _database
        .into(_database.workoutSets)
        .insert(
          WorkoutSetsCompanion.insert(
            workoutExerciseId: workoutExerciseId,
            weight: weight,
            repetitions: repetitions,
            completed: const Value(true),
            setNumber: setNumber,
          ),
        );
  }

  Future<double> _getPersonalRecord(int exerciseId) async {
    final workoutExercises = await (_database.select(
      _database.workoutExercises,
    )..where((item) => item.exerciseId.equals(exerciseId))).get();

    if (workoutExercises.isEmpty) {
      return 0;
    }

    double maxWeight = 0;

    for (final workoutExercise in workoutExercises) {
      final sets =
          await (_database.select(_database.workoutSets)..where(
                (item) => item.workoutExerciseId.equals(workoutExercise.id),
              ))
              .get();

      for (final set in sets) {
        if (set.weight > maxWeight) {
          maxWeight = set.weight;
        }
      }
    }

    return maxWeight;
  }

Future<double> _getPreviousPersonalRecord(int exerciseId) async {
  final workoutExercises =
      await (_database.select(_database.workoutExercises)..where(
        (item) =>
            item.exerciseId.equals(exerciseId) &
            item.workoutId.equals(_workoutId!).not(),
      )).get();

  if (workoutExercises.isEmpty) {
    return 0;
  }

  double maxWeight = 0;

  for (final workoutExercise in workoutExercises) {
    final sets =
        await (_database.select(_database.workoutSets)..where(
          (item) =>
              item.workoutExerciseId.equals(workoutExercise.id) &
              item.completed.equals(true),
        )).get();

    for (final set in sets) {
      if (set.weight > maxWeight) {
        maxWeight = set.weight;
      }
    }
  }

  return maxWeight;
}

  Future<List<WorkoutSet>> _getSavedSets(int exerciseId) async {
    if (_workoutId == null) {
      return [];
    }

    final workoutExercises =
        await (_database.select(_database.workoutExercises)..where(
              (item) =>
                  item.workoutId.equals(_workoutId!) &
                  item.exerciseId.equals(exerciseId),
            ))
            .get();

    if (workoutExercises.isEmpty) {
      return [];
    }

    return (_database.select(_database.workoutSets)
          ..where(
            (item) => item.workoutExerciseId.equals(workoutExercises.first.id),
          )
          ..orderBy([(item) => OrderingTerm(expression: item.setNumber)]))
        .get();
  }

  Future<WorkoutSet?> _getLastWorkoutSet(int exerciseId) async {
    // Alle bisherigen Workouts laden,
    // aber das aktuell laufende Workout ausschließen.
    final workouts =
        await (_database.select(_database.workouts)
              ..where(
                (workout) =>
                    workout.id.equals(_workoutId!).not() &
                    workout.completed.equals(true),
              )
              ..orderBy([
                (workout) => OrderingTerm(
                  expression: workout.date,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();

    for (final workout in workouts) {
      final workoutExercises =
          await (_database.select(_database.workoutExercises)..where(
                (item) =>
                    item.workoutId.equals(workout.id) &
                    item.exerciseId.equals(exerciseId),
              ))
              .get();

      if (workoutExercises.isEmpty) {
        continue;
      }

      final sets =
          await (_database.select(_database.workoutSets)
                ..where(
                  (item) =>
                      item.workoutExerciseId.equals(workoutExercises.first.id),
                )
                ..orderBy([
                  (item) => OrderingTerm(
                    expression: item.setNumber,
                    mode: OrderingMode.desc,
                  ),
                ]))
              .get();

      if (sets.isNotEmpty) {
        return sets.first;
      }
    }

    return null;
  }

  Future<void> _addSet(_WorkoutExerciseData data) async {
    if (_workoutId == null) return;

    final existing =
        await (_database.select(_database.workoutExercises)..where(
              (item) =>
                  item.workoutId.equals(_workoutId!) &
                  item.exerciseId.equals(data.exercise.id),
            ))
            .get();

    int workoutExerciseId;

    if (existing.isEmpty) {
      workoutExerciseId = await _database
          .into(_database.workoutExercises)
          .insert(
            WorkoutExercisesCompanion.insert(
              workoutId: _workoutId!,
              exerciseId: data.exercise.id,
              orderIndex: data.templateExercise.orderIndex,
            ),
          );
    } else {
      workoutExerciseId = existing.first.id;
    }

    final savedSets = await (_database.select(
      _database.workoutSets,
    )..where((item) => item.workoutExerciseId.equals(workoutExerciseId))).get();

    final setNumber = savedSets.length + 1;

    final lastSet = await _getLastWorkoutSet(data.exercise.id);

    String weightText = lastSet != null
        ? lastSet.weight.toString()
        : data.templateExercise.defaultWeight > 0
        ? data.templateExercise.defaultWeight.toString()
        : '';

    String repetitionsText = lastSet != null
        ? lastSet.repetitions.toString()
        : '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Satz $setNumber – ${data.exercise.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                onChanged: (value) {
                  weightText = value;
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Gewicht',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) {
                  repetitionsText = value;
                },
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Wiederholungen',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                final weight = double.tryParse(
                  weightText.trim().replaceAll(',', '.'),
                );

                final repetitions = int.tryParse(repetitionsText.trim());

                if (weight == null || repetitions == null) {
                  return;
                }

                Navigator.of(
                  dialogContext,
                ).pop({'weight': weight, 'repetitions': repetitions});
              },
              child: const Text('Satz speichern'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final weight = result['weight'] as double;
    final repetitions = result['repetitions'] as int;

    // Bisherigen persönlichen Rekord laden
    final previousRecord = await _getPersonalRecord(data.exercise.id);

    // Satz speichern
    await _saveSet(
      workoutExerciseId: workoutExerciseId,
      setNumber: setNumber,
      weight: weight,
      repetitions: repetitions,
    );

    await _loadCompletedSets();

    _startRestTimer();

    // Prüfen, ob es ein neuer Rekord ist
    final isNewRecord = weight > previousRecord;

    debugPrint(
      'PR CHECK: ${data.exercise.name} | '
      'alt=$previousRecord | neu=$weight | PR=$isNewRecord',
    );

    if (!mounted) return;

    if (isNewRecord) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🏆 Neuer persönlicher Rekord!\n'
            '${data.exercise.name}: $weight kg',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }

    setState(() {});

    if (!mounted) return;

    setState(() {});
  }

Future<List<String>> _getNewPersonalRecords() async {
  final newRecords = <String>[];

  for (final exercise in _exercises) {
    final previousRecord =
        await _getPreviousPersonalRecord(exercise.exercise.id);

    final currentSets =
        await _getSavedSets(exercise.exercise.id);

    double currentMax = 0;

    for (final set in currentSets) {
      if (set.completed && set.weight > currentMax) {
        currentMax = set.weight;
      }
    }

    if (currentMax > previousRecord) {
      newRecords.add(
        '${exercise.exercise.name}: '
        '${currentMax.toStringAsFixed(1)} kg',
      );
    }
  }

  return newRecords;
}

  Future<void> _finishWorkout() async {
    if (_workoutId == null) return;

    if (!mounted) return;

    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Training beenden?'),
          content: const Text('Möchtest du das Training wirklich beenden?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Beenden'),
            ),
          ],
        );
      },
    );

    if (shouldFinish != true || !mounted) return;

    // Gesamtzahl der geplanten Sätze
    int totalSets = 0;

    for (final exercise in _exercises) {
      totalSets += exercise.templateExercise.plannedSets;
    }

    final workoutDuration = _workoutStartTime == null
        ? Duration.zero
        : DateTime.now().difference(_workoutStartTime!);

    final durationMinutes = workoutDuration.inMinutes;

    // Aktuell abgeschlossene Sätze
    final completedSets = _completedSets;

    final newPersonalRecords = await _getNewPersonalRecords();

    // Trainingsvolumen berechnen
    double totalVolume = 0;

    for (final exercise in _exercises) {
      final sets = await _getSavedSets(exercise.exercise.id);

      for (final set in sets) {
        if (set.completed) {
          totalVolume += set.weight * set.repetitions;
        }
      }
    }

    if (!mounted) return;

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('🎉 Training abgeschlossen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stark! Dein Training ist fertig.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              Row(
                children: [
                  const Icon(Icons.timer),
                  const SizedBox(width: 12),
                  Text('Dauer: $durationMinutes Minuten'),
                ],
              ),

              const SizedBox(height: 12),

              if (newPersonalRecords.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Neue Persönliche Rekorde:',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    ...newPersonalRecords.map((record) => Text(record)),
                  ],
                )
              else
                const SizedBox(height: 20),

              Row(
                children: [
                  const Icon(Icons.fitness_center),
                  const SizedBox(width: 12),
                  Text('$completedSets / $totalSets Sätze'),
                ],
              ),

              const SizedBox(height: 16),

if (newPersonalRecords.isNotEmpty)
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Row(
        children: [
          Icon(
            Icons.emoji_events,
            color: Colors.amber,
          ),
          SizedBox(width: 12),
          Text(
            'Neue persönliche Rekorde!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      for (final record in newPersonalRecords)
        Padding(
          padding: const EdgeInsets.only(left: 36, bottom: 4),
          child: Text('🏆 $record'),
        ),
    ],
  )
else
  const Row(
    children: [
      Icon(Icons.emoji_events_outlined),
      SizedBox(width: 12),
      Text('Keine neuen PRs'),
    ],
  ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.scale),
                  const SizedBox(width: 12),
                  Text(
                    'Volumen: '
                    '${totalVolume.toStringAsFixed(1)} kg',
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.list_alt),
                  const SizedBox(width: 12),
                  Text('${_exercises.length} Übungen'),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Zurück'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Training speichern'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true || !mounted) return;

    await (_database.update(_database.workouts)
          ..where((workout) => workout.id.equals(_workoutId!)))
        .write(const WorkoutsCompanion(completed: Value(true)));

    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Widget _buildWorkoutProgress() {
    int totalSets = 0;

    for (final exercise in _exercises) {
      totalSets += exercise.templateExercise.plannedSets;
    }

    final progress = totalSets == 0
        ? 0.0
        : (_completedSets / totalSets).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Trainingsfortschritt',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_completedSets / $totalSets Sätze',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 6),
            Text(
              '${(progress * 100).round()} % abgeschlossen',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.workoutName),
          actions: [
            TextButton.icon(
              onPressed: _finishWorkout,
              icon: const Icon(Icons.check),
              label: const Text('Beenden'),
            ),
          ],
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.workoutName),
          actions: [
            TextButton.icon(
              onPressed: _finishWorkout,
              icon: const Icon(Icons.check),
              label: const Text('Beenden'),
            ),
          ],
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.workoutName),
        actions: [
          TextButton.icon(
            onPressed: _finishWorkout,
            icon: const Icon(Icons.check),
            label: const Text('Beenden'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_remainingRest > Duration.zero) _buildRestTimer(),

          _buildWorkoutProgress(),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final data = _exercises[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.exercise.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          '${data.templateExercise.plannedSets} Sätze • '
                          '${data.templateExercise.targetRepetitions} Wdh.',
                        ),

                        const SizedBox(height: 16),

                        FutureBuilder<WorkoutSet?>(
                          future: _getLastWorkoutSet(data.exercise.id),
                          builder: (context, snapshot) {
                            final lastSet = snapshot.data;

                            if (lastSet == null) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.history,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Letztes Training: '
                                      '${lastSet.weight} kg × '
                                      '${lastSet.repetitions} Wdh.',
                                      style: const TextStyle(
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 8),

                        FutureBuilder<List<WorkoutSet>>(
                          future: _getSavedSets(data.exercise.id),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: CircularProgressIndicator(),
                              );
                            }

                            final sets = snapshot.data ?? [];

                            if (sets.isEmpty) {
                              return const Text(
                                'Noch keine Sätze gespeichert',
                                style: TextStyle(color: Colors.grey),
                              );
                            }

                            return Column(
                              children: [
                                for (final set in sets)
                                  Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        child: Text('${set.setNumber}'),
                                      ),
                                      title: Text(
                                        '${set.weight} kg × '
                                        '${set.repetitions} Wdh.',
                                      ),
                                      trailing: set.completed
                                          ? const Icon(Icons.check_circle)
                                          : const Icon(Icons.circle_outlined),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 8),

                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _addSet(data),
                            icon: const Icon(Icons.add),
                            label: const Text('Satz hinzufügen'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestTimer() {
    final isPaused = !_restTimerRunning;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.timer, size: 28),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Satzpause',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _formatRestTime(_remainingRest),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            IconButton(
              tooltip: isPaused ? 'Fortsetzen' : 'Pause',
              onPressed: isPaused ? _resumeRestTimer : _pauseRestTimer,
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
            ),

            IconButton(
              tooltip: 'Überspringen',
              onPressed: _skipRestTimer,
              icon: const Icon(Icons.skip_next),
            ),

            IconButton(
              tooltip: 'Timer einstellen',
              onPressed: _showRestTimerSettings,
              icon: const Icon(Icons.settings),
            ),
          ],
        ),
      ),
    );
  }
} // ← GANZ WICHTIG: schließt _ActiveWorkoutPageState

class _WorkoutExerciseData {
  final TemplateExercise templateExercise;
  final Exercise exercise;

  const _WorkoutExerciseData({
    required this.templateExercise,
    required this.exercise,
  });
}
