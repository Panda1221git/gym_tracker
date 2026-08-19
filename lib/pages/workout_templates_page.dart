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
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Neuer Trainingsplan'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'z. B. Push',
              border: OutlineInputBorder(),
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

    await _database.into(_database.workoutTemplates).insert(
          WorkoutTemplatesCompanion.insert(
            userId: user.id,
            name: result,
            orderIndex: 0,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Trainingspläne'),
      ),
      body: StreamBuilder<List<WorkoutTemplate>>(
        stream: _database.select(_database.workoutTemplates).watch(),
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

          final templates = snapshot.data ?? [];

          if (templates.isEmpty) {
            return const Center(
              child: Text(
                'Noch keine Trainingspläne vorhanden',
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.fitness_center),
                  ),
                  title: Text(template.name),
                  subtitle: const Text(
                    'Übungen verwalten',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TemplateExercisesPage(
                          template: template,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTemplateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Plan erstellen'),
      ),
    );
  }
}