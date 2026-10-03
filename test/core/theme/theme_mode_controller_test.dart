import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onboard/core/theme/theme_mode_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeThemeStore implements ThemePreferenceStore {
  _FakeThemeStore([this.value = ThemeMode.system]);

  ThemeMode value;
  int writes = 0;

  @override
  ThemeMode read() => value;

  @override
  Future<void> write(ThemeMode mode) async {
    value = mode;
    writes++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeModeController', () {
    test('defaults to system when nothing is stored', () {
      final store = _FakeThemeStore();
      expect(ThemeModeController(store).state, ThemeMode.system);
    });

    test('restores the stored mode on construction', () {
      final store = _FakeThemeStore(ThemeMode.dark);
      expect(ThemeModeController(store).state, ThemeMode.dark);
    });

    test('setMode updates state and persists exactly once', () async {
      final store = _FakeThemeStore();
      final controller = ThemeModeController(store);

      await controller.setMode(ThemeMode.light);

      expect(controller.state, ThemeMode.light);
      expect(store.value, ThemeMode.light);
      expect(store.writes, 1);
    });

    test('setMode with the current mode does not write', () async {
      final store = _FakeThemeStore(ThemeMode.dark);
      final controller = ThemeModeController(store);

      await controller.setMode(ThemeMode.dark);

      expect(store.writes, 0);
    });

    test('provider reads the overridden store', () {
      final container = ProviderContainer(
        overrides: [
          themeStoreProvider.overrideWithValue(_FakeThemeStore(ThemeMode.dark)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(themeModeProvider), ThemeMode.dark);
    });
  });

  group('SharedPrefsThemeStore', () {
    test('round-trips a mode through shared_preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPrefsThemeStore(prefs);

      expect(store.read(), ThemeMode.system);

      await store.write(ThemeMode.dark);
      expect(store.read(), ThemeMode.dark);

      await store.write(ThemeMode.light);
      expect(store.read(), ThemeMode.light);
    });

    test('an unrecognised stored value falls back to system', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'sepia'});
      final prefs = await SharedPreferences.getInstance();

      expect(SharedPrefsThemeStore(prefs).read(), ThemeMode.system);
    });
  });
}
