import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;

import '../services/app_database.dart';

class ExercisesPage extends StatefulWidget {
  const ExercisesPage({super.key});

  @override
  State<ExercisesPage> createState() => _ExercisesPageState();
}

class _ExercisesPageState extends State<ExercisesPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _equipmentController = TextEditingController();

  final AppDatabase _database = AppDatabase();

  String _selectedMuscleGroup = 'Brust';

  final List<String> _muscleGroups = [
    'Brust',
    'Rücken',
    'Schultern',
    'Bizeps',
    'Trizeps',
    'Beine',
    'Bauch',
    'Waden',
    'Unterarme',
    'Ganzkörper',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _equipmentController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // Übung speichern
  // --------------------------------------------------

  Future<void> _saveExercise() async {
    final name = _nameController.text.trim();
    final equipment = _equipmentController.text.trim();

    if (name.isEmpty) {
      return;
    }

    await _database.into(_database.exercises).insert(
          ExercisesCompanion.insert(
            name: name,
            muscleGroup: _selectedMuscleGroup,
            equipment: Value(
              equipment.isEmpty ? null : equipment,
            ),
          ),
        );

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Übung gespeichert 💪'),
      ),
    );
  }

  // --------------------------------------------------
  // Übung löschen
  // --------------------------------------------------

  Future<void> _deleteExercise(int id) async {
    await (_database.delete(_database.exercises)
          ..where((exercise) => exercise.id.equals(id)))
        .go();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Übung gelöscht'),
      ),
    );
  }

  // --------------------------------------------------
  // Übung bearbeiten
  // --------------------------------------------------

  void _showEditExerciseDialog(Exercise exercise) {
    _nameController.text = exercise.name;
    _equipmentController.text = exercise.equipment ?? '';
    _selectedMuscleGroup = exercise.muscleGroup;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Übung bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Übungsname',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMuscleGroup,
                      decoration: const InputDecoration(
                        labelText: 'Muskelgruppe',
                        border: OutlineInputBorder(),
                      ),
                      items: _muscleGroups.map((muscleGroup) {
                        return DropdownMenuItem(
                          value: muscleGroup,
                          child: Text(muscleGroup),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            _selectedMuscleGroup = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _equipmentController,
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: () async {
                    final name = _nameController.text.trim();
                    final equipment = _equipmentController.text.trim();

                    if (name.isEmpty) {
                      return;
                    }

                    await (_database.update(_database.exercises)
                          ..where((item) => item.id.equals(exercise.id)))
                        .write(
                      ExercisesCompanion(
                        name: Value(name),
                        muscleGroup: Value(_selectedMuscleGroup),
                        equipment: Value(
                          equipment.isEmpty ? null : equipment,
                        ),
                      ),
                    );

                    if (!context.mounted) return;

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Übung aktualisiert 💪'),
                      ),
                    );
                  },
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------
  // Neue Übung hinzufügen
  // --------------------------------------------------

  void _showAddExerciseDialog() {
    _nameController.clear();
    _equipmentController.clear();
    _selectedMuscleGroup = 'Brust';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Neue Übung'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Übungsname',
                        hintText: 'z. B. Bankdrücken',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedMuscleGroup,
                      decoration: const InputDecoration(
                        labelText: 'Muskelgruppe',
                        border: OutlineInputBorder(),
                      ),
                      items: _muscleGroups.map((muscleGroup) {
                        return DropdownMenuItem(
                          value: muscleGroup,
                          child: Text(muscleGroup),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            _selectedMuscleGroup = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _equipmentController,
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        hintText: 'z. B. Langhantel',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Abbrechen'),
                ),
                FilledButton(
                  onPressed: _saveExercise,
                  child: const Text('Speichern'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --------------------------------------------------
  // Oberfläche
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Übungen'),
      ),
      body: StreamBuilder<List<Exercise>>(
        stream: _database.select(_database.exercises).watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Fehler beim Laden: ${snapshot.error}',
              ),
            );
          }

          final exercises = snapshot.data ?? [];

          if (exercises.isEmpty) {
            return const Center(
              child: Text(
                'Noch keine Übungen vorhanden',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center),
                  ),
                  title: Text(exercise.name),
                  subtitle: Text(
                    '${exercise.muscleGroup}'
                    '${exercise.equipment != null ? ' • ${exercise.equipment}' : ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showEditExerciseDialog(exercise);
                      } else if (value == 'delete') {
                        _deleteExercise(exercise.id);
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExerciseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}