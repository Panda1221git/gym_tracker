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

/// Ein komplettes Training
class Workouts extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get userId => integer().references(AppUsers, #id)();

  TextColumn get name => text()();

  DateTimeColumn get date => dateTime()();
}

/// Eine Übung innerhalb eines Trainings
class WorkoutExercises extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workoutId => integer().references(Workouts, #id)();

  IntColumn get exerciseId => integer().references(Exercises, #id)();

  IntColumn get orderIndex => integer()();
}

/// Ein einzelner Satz
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
    Workouts,
    WorkoutExercises,
    WorkoutSets,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(
          executor ??
              driftDatabase(
                name: 'gym_tracker',
              ),
        );

  @override
  int get schemaVersion => 1;
}