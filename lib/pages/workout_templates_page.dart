import 'package:flutter/material.dart';

import '../services/app_database.dart';
import '../services/database_service.dart';
import 'template_exercises_page.dart';

class WorkoutTemplatesPage extends StatefulWidget {
  const WorkoutTemplatesPage({super.key});

  @override
  State<WorkoutTemplatesPage> createState() => _WorkoutTemplatesPageState();
}

class _WorkoutTemplatesPageState extends State<WorkoutTemplatesPage> {
  final AppDatabase _database = DatabaseService.database;

  Future<void> _showAddTemplateDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final nameController = TextEditingController();

        return AlertDialog(
          title: const Text(
            'Neuer Trainingsplan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'z. B. Push',
              prefixIcon: Icon(Icons.fitness_center),
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
                final name = nameController.text.trim();

                if (name.isEmpty) {
                  return;
                }

                Navigator.of(dialogContext).pop(name);
              },
              child: const Text('Erstellen'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty || !mounted) {
      return;
    }

    final user = await DatabaseService.getOrCreateDefaultUser();

    await _database
        .into(_database.workoutTemplates)
        .insert(
          WorkoutTemplatesCompanion.insert(
            userId: user.id,
            name: result,
            orderIndex: 0,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meine Trainingspläne',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: StreamBuilder<List<WorkoutTemplate>>(
        stream: _database.select(_database.workoutTemplates).watch(),

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

          final templates = snapshot.data ?? [];

          if (templates.isEmpty) {
            return _EmptyWorkoutTemplates(
              accent: accent,
              onCreate: _showAddTemplateDialog,
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              // ============================================================
              // Header
              // ============================================================
              const Text(
                'DEINE PLÄNE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                '${templates.length} '
                '${templates.length == 1 ? 'Trainingsplan' : 'Trainingspläne'}',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),

              const SizedBox(height: 16),

              // ============================================================
              // Trainingspläne
              // ============================================================
              for (final template in templates)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              TemplateExercisesPage(template: template),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              Icons.fitness_center,
                              color: accent,
                              size: 27,
                            ),
                          ),

                          const SizedBox(width: 15),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 5),

                                Text(
                                  'Übungen verwalten',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade500,
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
        onPressed: _showAddTemplateDialog,
        backgroundColor: accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text(
          'Plan erstellen',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _EmptyWorkoutTemplates extends StatelessWidget {
  final Color accent;
  final VoidCallback onCreate;

  const _EmptyWorkoutTemplates({required this.accent, required this.onCreate});

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
              'Noch kein Trainingsplan',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Erstelle deinen ersten Trainingsplan '
              'und füge anschließend deine Übungen hinzu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade400, height: 1.4),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Ersten Plan erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}
