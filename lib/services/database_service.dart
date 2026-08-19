import 'app_database.dart';

class DatabaseService {
  static final AppDatabase database = AppDatabase();

  static Future<AppUser> getOrCreateDefaultUser() async {
    final existingUsers = await database.select(database.appUsers).get();

    if (existingUsers.isNotEmpty) {
      return existingUsers.first;
    }

    final id = await database.into(database.appUsers).insert(
          AppUsersCompanion.insert(
            name: 'Mein Benutzer',
          ),
        );

    return (database.select(database.appUsers)
          ..where((user) => user.id.equals(id)))
        .getSingle();
  }
}