import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the chosen [ThemeMode] is kept between launches.
///
/// Reading is synchronous so the saved mode can be applied on the very first
/// frame; there is no flash of the wrong theme on a cold start.
abstract class ThemePreferenceStore {
  ThemeMode read();
  Future<void> write(ThemeMode mode);
}

/// The real store, backed by `shared_preferences`.
class SharedPrefsThemeStore implements ThemePreferenceStore {
  const SharedPrefsThemeStore(this._prefs);

  static const String _key = 'theme_mode';

  final SharedPreferences _prefs;

  @override
  ThemeMode read() => switch (_prefs.getString(_key)) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  @override
  Future<void> write(ThemeMode mode) => _prefs.setString(_key, mode.name);
}

/// Overridden in `main` with a [SharedPrefsThemeStore] and in tests with a fake.
final themeStoreProvider = Provider<ThemePreferenceStore>((ref) {
  throw UnimplementedError('themeStoreProvider must be overridden');
});

/// The active theme mode. Defaults to following the system until changed.
final themeModeProvider = StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(ref.watch(themeStoreProvider)),
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._store) : super(_store.read());

  final ThemePreferenceStore _store;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    await _store.write(mode);
  }
}
