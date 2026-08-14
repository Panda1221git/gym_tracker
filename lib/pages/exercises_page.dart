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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Übungen'),
      ),
      body: const Center(
        child: Text(
          'Noch keine Übungen vorhanden',
          style: TextStyle(fontSize: 18),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExerciseDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}