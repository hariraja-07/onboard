import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_controller.dart';
import 'core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Content draws behind the status and navigation bars; the app insets its
  // own content with SafeArea or padding. Android 15+ enforces this regardless,
  // so setting it explicitly keeps API 34 and below behaving the same way.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        themeStoreProvider.overrideWithValue(SharedPrefsThemeStore(prefs)),
      ],
      child: const OnBoardApp(),
    ),
  );
}

class OnBoardApp extends ConsumerWidget {
  const OnBoardApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'OnBoard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => _SystemBarsFollowTheme(child: child),
    );
  }
}

/// Keeps the status bar icon colour matched to the resolved brightness.
///
/// Without this the icons stay whatever the system last set, so switching to
/// dark mode at runtime leaves dark icons on a dark app bar and the clock
/// disappears. Resolving through [MaterialApp] rather than [MediaQuery] means
/// this tracks the user's theme choice, not just the OS setting.
class _SystemBarsFollowTheme extends StatelessWidget {
  const _SystemBarsFollowTheme({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
