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

  Stream<List<Exercise>> get _exercisesStream =>
      _database.select(_database.exercises).watch();

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

  // ============================================================
  // Übung speichern
  // ============================================================

  Future<void> _saveExercise() async {
    final name = _nameController.text.trim();
    final equipment = _equipmentController.text.trim();

    if (name.isEmpty) {
      return;
    }

    await _database
        .into(_database.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name,
            muscleGroup: _selectedMuscleGroup,
            equipment: Value(equipment.isEmpty ? null : equipment),
          ),
        );

    if (!mounted) return;

    Navigator.pop(context);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Übung gespeichert 💪')));
  }

  // ============================================================
  // Übung löschen
  // ============================================================

  Future<void> _deleteExercise(int id) async {
    await (_database.delete(
      _database.exercises,
    )..where((exercise) => exercise.id.equals(id))).go();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Übung gelöscht')));
  }

  // ============================================================
  // Löschen bestätigen
  // ============================================================

  Future<void> _confirmDeleteExercise(Exercise exercise) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Übung löschen?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text('Möchtest du „${exercise.name}“ wirklich löschen?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Löschen'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _deleteExercise(exercise.id);
    }
  }

  // ============================================================
  // Übung bearbeiten
  // ============================================================

  void _showEditExerciseDialog(Exercise exercise) {
    _nameController.text = exercise.name;
    _equipmentController.text = exercise.equipment ?? '';
    _selectedMuscleGroup = exercise.muscleGroup;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Übung bearbeiten',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Übungsname',
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                    ),

                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedMuscleGroup,
                      decoration: const InputDecoration(
                        labelText: 'Muskelgruppe',
                        prefixIcon: Icon(Icons.accessibility_new),
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

                    const SizedBox(height: 14),

                    TextField(
                      controller: _equipmentController,
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        hintText: 'z. B. Langhantel',
                        prefixIcon: Icon(Icons.sports_gymnastics),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
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

                    await (_database.update(
                      _database.exercises,
                    )..where((item) => item.id.equals(exercise.id))).write(
                      ExercisesCompanion(
                        name: Value(name),
                        muscleGroup: Value(_selectedMuscleGroup),
                        equipment: Value(equipment.isEmpty ? null : equipment),
                      ),
                    );

                    if (!context.mounted) return;

                    Navigator.pop(dialogContext);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Übung aktualisiert 💪')),
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

  // ============================================================
  // Neue Übung
  // ============================================================

  void _showAddExerciseDialog() {
    _nameController.clear();
    _equipmentController.clear();
    _selectedMuscleGroup = 'Brust';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Neue Übung',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _nameController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Übungsname',
                        hintText: 'z. B. Bankdrücken',
                        prefixIcon: Icon(Icons.fitness_center),
                      ),
                    ),

                    const SizedBox(height: 14),

                    DropdownButtonFormField<String>(
                      initialValue: _selectedMuscleGroup,
                      decoration: const InputDecoration(
                        labelText: 'Muskelgruppe',
                        prefixIcon: Icon(Icons.accessibility_new),
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

                    const SizedBox(height: 14),

                    TextField(
                      controller: _equipmentController,
                      decoration: const InputDecoration(
                        labelText: 'Equipment',
                        hintText: 'z. B. Langhantel',
                        prefixIcon: Icon(Icons.sports_gymnastics),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
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

  // ============================================================
  // Oberfläche
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meine Übungen',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: StreamBuilder<List<Exercise>>(
        stream: _exercisesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Fehler beim Laden: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final exercises = snapshot.data ?? [];

          if (exercises.isEmpty) {
            return _EmptyExercises(
              accent: accent,
              onAdd: _showAddExerciseDialog,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              // ==========================================================
              // Header
              // ==========================================================
              const Text(
                'ÜBUNGSKATALOG',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '${exercises.length} '
                '${exercises.length == 1 ? 'Übung' : 'Übungen'}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),

              const SizedBox(height: 18),

              // ==========================================================
              // Übungen
              // ==========================================================
              for (final exercise in exercises)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      _showEditExerciseDialog(exercise);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: accent,
                              size: 25,
                            ),
                          ),

                          const SizedBox(width: 14),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Wrap(
                                  spacing: 6,
                                  runSpacing: 5,
                                  children: [
                                    _InfoChip(
                                      icon: Icons.accessibility_new,
                                      text: exercise.muscleGroup,
                                      accent: accent,
                                    ),

                                    if (exercise.equipment != null)
                                      _InfoChip(
                                        icon: Icons.sports_gymnastics,
                                        text: exercise.equipment!,
                                        accent: accent,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey.shade400,
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showEditExerciseDialog(exercise);
                              }

                              if (value == 'delete') {
                                _confirmDeleteExercise(exercise);
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
                  ),
                ),
            ],
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddExerciseDialog,
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
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: Colors.grey.shade300, fontSize: 11),
          ),
        ],
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
              'Noch keine Übungen',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Erstelle deine erste Übung und '
              'baue deinen persönlichen Übungskatalog auf.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, height: 1.4),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Erste Übung erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}
