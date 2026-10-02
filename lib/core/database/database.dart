// Placeholder database service — replace with Drift when tables are defined.
// This keeps the app launching offline without cloud dependencies.

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  bool _initialized = false;

  Future<void> init() async {
    _initialized = true;
  }

  bool get isInitialized => _initialized;
}