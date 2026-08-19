import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Benutzer der App
class AppUsers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get email => text().nullable()();
}

/// Alle verfügbaren Übungen
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text()();

  TextColumn get muscleGroup => text()();

  TextColumn get equipment => text().nullable()();
}

/// Ein Trainingsplan, z. B. Push / Pull / Legs
class WorkoutTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().references(AppUsers, #id)();

  TextColumn get name => text()();

  IntColumn get orderIndex => integer()();
}

/// Eine Übung innerhalb eines Trainingsplans
class TemplateExercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get templateId => integer().references(WorkoutTemplates, #id)();

  IntColumn get exerciseId => integer().references(Exercises, #id)();

  IntColumn get orderIndex => integer()();

  /// Anzahl der geplanten Sätze
  IntColumn get plannedSets => integer()();

  /// Ziel-Wiederholungen, z. B. 8-10
  TextColumn get targetRepetitions => text()();

  /// Das aktuell verwendete Standardgewicht
  RealColumn get defaultWeight => real().withDefault(const Constant(0))();
}

/// Ein tatsächliches Training
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().references(AppUsers, #id)();

  IntColumn get templateId => integer().references(WorkoutTemplates, #id)();

  TextColumn get name => text()();

  DateTimeColumn get date => dateTime()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();
}

/// Eine Übung innerhalb eines tatsächlichen Trainings
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workoutId => integer().references(Workouts, #id)();

  IntColumn get exerciseId => integer().references(Exercises, #id)();

  IntColumn get orderIndex => integer()();
}

/// Ein tatsächlich ausgeführter Satz
class WorkoutSets extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workoutExerciseId =>
      integer().references(WorkoutExercises, #id)();

  RealColumn get weight => real()();

  IntColumn get repetitions => integer()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  IntColumn get setNumber => integer()();
}

@DriftDatabase(
  tables: [
    AppUsers,
    Exercises,
    WorkoutTemplates,
    TemplateExercises,
    Workouts,
    WorkoutExercises,
    WorkoutSets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'gym_tracker'));

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.createTable(workoutTemplates);
        await m.createTable(templateExercises);
      }

      if (from < 3) {
        await customStatement(
          'ALTER TABLE workouts '
          'ADD COLUMN completed BOOLEAN NOT NULL DEFAULT 0',
        );
      }

      if (from < 4) {
        await customStatement(
          'ALTER TABLE workouts '
          'ADD COLUMN archived BOOLEAN NOT NULL DEFAULT 0',
        );
      }
    },
  );
}
