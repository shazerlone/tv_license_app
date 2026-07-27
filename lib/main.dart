import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'state/session.dart';
import 'state/app_state.dart';
import 'state/theme_controller.dart';
import 'services/api_client.dart';
import 'services/auth_api.dart';
import 'services/auth_store.dart';
import 'config.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MillimoreApp());
}

class MillimoreApp extends StatefulWidget {
  const MillimoreApp({super.key});

  @override
  State<MillimoreApp> createState() => _MillimoreAppState();
}

class _MillimoreAppState extends State<MillimoreApp> {
  final SessionController _session = SessionController();
  final AppState _appState = AppState();
  final ThemeController _theme = ThemeController();
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  bool _booting = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    // Global 401 handler: token rejected/expired → sign out to login.
    ApiClient.instance.onUnauthorized = _forceSignOut;
    _restore();
  }

  void _forceSignOut() {
    _session.signOut();
    _navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  /// Remember-me: if a session is persisted, restore it and open straight to
  /// the home screen (no splash/onboarding animations on return visits).
  Future<void> _restore() async {
    await _theme.load();
    final data = await AuthStore.load();
    if (data.token != null) ApiClient.instance.setToken(data.token);
    if (data.user != null) {
      _session.restore(data.user!);
      _hasSession = true;
    }
    if (mounted) setState(() => _booting = false);

    // Validate the persisted token in the background. If it's still good we
    // refresh the user; if it's rejected the 401 handler signs out; network
    // errors are ignored so the app still works offline with the cached user.
    if (kUseBackend && data.token != null) {
      try {
        final fresh = await AuthApi.me();
        if (mounted) _session.applyBackendSession(fresh);
      } catch (_) {/* offline or already handled by 401 hook */}
    }
  }

  @override
  void dispose() {
    _session.dispose();
    _appState.dispose();
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platform = MediaQuery.maybeOf(context)?.platformBrightness ??
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    return SessionScope(
      controller: _session,
      child: AppStateScope(
        controller: _appState,
        child: ThemeScope(
          controller: _theme,
          child: ListenableBuilder(
            listenable: _theme,
            builder: (context, _) {
              final dark = _theme.isDark(platform);
              // Set the global palette flag BEFORE the tree builds so every
              // AppColors getter resolves to the active theme.
              AppColors.isDark = dark;
              SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
              ));
              return MaterialApp(
                title: 'millimore',
                navigatorKey: _navKey,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                darkTheme: AppTheme.dark,
                themeMode: _theme.mode,
                builder: (context, child) {
                  final mq = MediaQuery.of(context);
                  return MediaQuery(
                    data: mq.copyWith(
                      textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.05),
                    ),
                    child: child!,
                  );
                },
                home: _booting
                    ? ColoredBox(color: AppColors.background)
                    : (_hasSession ? const HomeScreen() : const SplashScreen()),
              );
            },
          ),
        ),
      ),
    );
  }
}
