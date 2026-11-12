import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qout/core/database/database.dart';

/// The app's local database, opened once and closed with the provider scope.
/// Tests override it with an in-memory database.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.open();
  ref.onDispose(database.close);
  return database;
});
