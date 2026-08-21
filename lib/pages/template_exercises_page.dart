import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../services/app_database.dart';
import '../services/database_service.dart';
import '../pages/active_workout_page.dart';

class TemplateExercisesPage extends StatefulWidget {
  final WorkoutTemplate template;

  const TemplateExercisesPage({super.key, required this.template});

  @override
  State<TemplateExercisesPage> createState() => _TemplateExercisesPageState();
}

class _TemplateExercisesPageState extends State<TemplateExercisesPage> {
  final AppDatabase _database = DatabaseService.database;

  List<TypedResult> _results = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final query = _database.select(_database.templateExercises).join([
      innerJoin(
        _database.exercises,
        _database.exercises.id.equalsExp(
          _database.templateExercises.exerciseId,
        ),
      ),
    ]);

    query.where(
      _database.templateExercises.templateId.equals(widget.template.id),
    );

    query.orderBy([
      OrderingTerm(expression: _database.templateExercises.orderIndex),
    ]);

    final results = await query.get();

    if (!mounted) return;

    setState(() {
      _results = results;
      _isLoading = false;
    });
  }

  Future<void> _addExercise() async {
    final exercises = await _database.select(_database.exercises).get();

    if (!mounted) return;

    if (exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst unter „Übungen“ eine Übung erstellen.'),
        ),
      );

      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        final accent = Theme.of(context).colorScheme.primary;

        return AlertDialog(
          title: const Text(
            'Übung hinzufügen',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: exercises.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final exercise = exercises[index];

                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.fitness_center, color: accent),
                    ),
                    title: Text(
                      exercise.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${exercise.muscleGroup}'
                      '${exercise.equipment != null ? ' • ${exercise.equipment}' : ''}',
                    ),
                    onTap: () async {
                      final existing =
                          await (_database.select(
                                _database.templateExercises,
                              )..where(
                                (item) =>
                                    item.templateId.equals(widget.template.id) &
                                    item.exerciseId.equals(exercise.id),
                              ))
                              .get();

                      if (existing.isEmpty) {
                        await _database
                            .into(_database.templateExercises)
                            .insert(
                              TemplateExercisesCompanion.insert(
                                templateId: widget.template.id,
                                exerciseId: exercise.id,
                                orderIndex: index,
                                plannedSets: 3,
                                targetRepetitions: '8-12',
                                defaultWeight: const Value(0),
                              ),
                            );
                      }

                      if (!dialogContext.mounted) return;

                      Navigator.of(dialogContext).pop();
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    await _loadExercises();
  }

  Future<void> _deleteExercise(int id) async {
    await (_database.delete(
      _database.templateExercises,
    )..where((item) => item.id.equals(id))).go();

    await _loadExercises();
  }

  Future<void> _editExercise(
    TemplateExercise templateExercise,
    Exercise exercise,
  ) async {
    final setsController = TextEditingController(
      text: templateExercise.plannedSets.toString(),
    );

    final repetitionsController = TextEditingController(
      text: templateExercise.targetRepetitions,
    );

    final weightController = TextEditingController(
      text: templateExercise.defaultWeight == 0
          ? ''
          : templateExercise.defaultWeight.toString(),
    );

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              exercise.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: setsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Sätze',
                      hintText: 'z. B. 3',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: repetitionsController,
                    decoration: const InputDecoration(
                      labelText: 'Ziel-Wiederholungen',
                      hintText: 'z. B. 8-12',
                      prefixIcon: Icon(Icons.replay),
                    ),
                  ),

                  const SizedBox(height: 14),

                  TextField(
                    controller: weightController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Standardgewicht',
                      hintText: 'z. B. 82,5',
                      prefixIcon: Icon(Icons.monitor_weight_outlined),
                      suffixText: 'kg',
                    ),
                  ),
                ],
              ),
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
                  final sets = int.tryParse(setsController.text.trim());

                  final repetitions = repetitionsController.text.trim();

                  final weightText = weightController.text.trim().replaceAll(
                    ',',
                    '.',
                  );

                  final weight = double.tryParse(weightText);

                  if (sets == null || sets <= 0 || repetitions.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop({
                    'sets': sets,
                    'repetitions': repetitions,
                    'weight': weight ?? 0.0,
                  });
                },
                child: const Text('Speichern'),
              ),
            ],
          );
        },
      );

      if (result == null || !mounted) return;

      final newSets = result['sets'] as int;
      final newRepetitions = result['repetitions'] as String;
      final newWeight = result['weight'] as double;

      await (_database.update(
        _database.templateExercises,
      )..where((item) => item.id.equals(templateExercise.id))).write(
        TemplateExercisesCompanion(
          plannedSets: Value(newSets),
          targetRepetitions: Value(newRepetitions),
          defaultWeight: Value(newWeight),
        ),
      );

      await _loadExercises();
    } finally {
      setsController.dispose();
      repetitionsController.dispose();
      weightController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.template.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.template.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Training starten',
            icon: const Icon(Icons.play_arrow),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ActiveWorkoutPage(
                    templateId: widget.template.id,
                    workoutName: widget.template.name,
                  ),
                ),
              );
            },
          ),
        ],
      ),

      body: _results.isEmpty
          ? _EmptyExercises(accent: accent, onAdd: _addExercise)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                // ==========================================================
                // Header
                // ==========================================================
                Text(
                  widget.template.name,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '${_results.length} '
                  '${_results.length == 1 ? 'Übung' : 'Übungen'}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                ),

                const SizedBox(height: 20),

                // ==========================================================
                // Übungen
                // ==========================================================
                for (int index = 0; index < _results.length; index++) ...[
                  _buildExerciseCard(context, _results[index], index, accent),
                  const SizedBox(height: 10),
                ],
              ],
            ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        backgroundColor: accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'Übung hinzufügen',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildExerciseCard(
    BuildContext context,
    TypedResult result,
    int index,
    Color accent,
  ) {
    final templateExercise = result.readTable(_database.templateExercises);

    final exercise = result.readTable(_database.exercises);

    final weightText = templateExercise.defaultWeight > 0
        ? ' • ${templateExercise.defaultWeight} kg'
        : '';

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Nummer
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 14),

            // Übungsinformationen
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    '${templateExercise.plannedSets} Sätze • '
                    '${templateExercise.targetRepetitions} Wdh.'
                    '$weightText',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  ),
                ],
              ),
            ),

            // Menü
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: Colors.grey.shade400),
              onSelected: (value) {
                if (value == 'edit') {
                  _editExercise(templateExercise, exercise);
                } else if (value == 'delete') {
                  _deleteExercise(templateExercise.id);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined),
                      SizedBox(width: 10),
                      Text('Bearbeiten'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline),
                      SizedBox(width: 10),
                      Text('Löschen'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyExercises extends StatelessWidget {
  final Color accent;
  final VoidCallback onAdd;

  const _EmptyExercises({required this.accent, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.fitness_center, size: 40, color: accent),
            ),

            const SizedBox(height: 22),

            const Text(
              'Noch keine Übungen',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Füge Übungen zu deinem Trainingsplan hinzu, '
              'damit du direkt loslegen kannst.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, height: 1.4),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Übung hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}
