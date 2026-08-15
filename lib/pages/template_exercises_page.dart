import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../services/app_database.dart';

class TemplateExercisesPage extends StatefulWidget {
  final WorkoutTemplate template;

  const TemplateExercisesPage({
    super.key,
    required this.template,
  });

  @override
  State<TemplateExercisesPage> createState() =>
      _TemplateExercisesPageState();
}

class _TemplateExercisesPageState extends State<TemplateExercisesPage> {
  final AppDatabase _database = AppDatabase();

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
      _database.templateExercises.templateId.equals(
        widget.template.id,
      ),
    );

    query.orderBy([
      OrderingTerm(
        expression: _database.templateExercises.orderIndex,
      ),
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
          content: Text(
            'Bitte zuerst unter „Übungen“ eine Übung erstellen.',
          ),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Übung hinzufügen'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];

                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center),
                  ),
                  title: Text(exercise.name),
                  subtitle: Text(
                    '${exercise.muscleGroup}'
                    '${exercise.equipment != null ? ' • ${exercise.equipment}' : ''}',
                  ),
                  onTap: () async {
                    final existing = await (_database
                            .select(_database.templateExercises)
                          ..where(
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
    await (_database.delete(_database.templateExercises)
          ..where((item) => item.id.equals(id)))
        .go();

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

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(exercise.name),
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
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: repetitionsController,
                  decoration: const InputDecoration(
                    labelText: 'Ziel-Wiederholungen',
                    hintText: 'z. B. 8-12',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Standardgewicht',
                    hintText: 'z. B. 82,5',
                    suffixText: 'kg',
                    border: OutlineInputBorder(),
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
                final sets = int.tryParse(
                  setsController.text.trim(),
                );

                final repetitions =
                    repetitionsController.text.trim();

                final weightText =
                    weightController.text.trim().replaceAll(',', '.');

                final weight = double.tryParse(weightText);

                if (sets == null ||
                    sets <= 0 ||
                    repetitions.isEmpty) {
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

    setsController.dispose();
    repetitionsController.dispose();
    weightController.dispose();

    if (result == null) return;

    final newSets = result['sets'] as int;
    final newRepetitions = result['repetitions'] as String;
    final newWeight = result['weight'] as double;

    // Dialog ist bereits geschlossen.
    // Erst jetzt Datenbank ändern.
    await (_database.update(_database.templateExercises)
          ..where(
            (item) => item.id.equals(templateExercise.id),
          ))
        .write(
      TemplateExercisesCompanion(
        plannedSets: Value(newSets),
        targetRepetitions: Value(newRepetitions),
        defaultWeight: Value(newWeight),
      ),
    );

    await _loadExercises();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.template.name),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.template.name),
      ),
      body: _results.isEmpty
          ? const Center(
              child: Text(
                'Noch keine Übungen hinzugefügt',
                style: TextStyle(fontSize: 18),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final templateExercise =
                    _results[index].readTable(
                  _database.templateExercises,
                );

                final exercise =
                    _results[index].readTable(
                  _database.exercises,
                );

                final weightText =
                    templateExercise.defaultWeight > 0
                        ? ' • ${templateExercise.defaultWeight} kg'
                        : '';

                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.fitness_center),
                    ),
                    title: Text(
                      exercise.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      '${templateExercise.plannedSets} Sätze • '
                      '${templateExercise.targetRepetitions} Wdh.'
                      '$weightText',
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editExercise(
                            templateExercise,
                            exercise,
                          );
                        } else if (value == 'delete') {
                          _deleteExercise(
                            templateExercise.id,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Bearbeiten'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Löschen'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Übung hinzufügen'),
      ),
    );
  }
}