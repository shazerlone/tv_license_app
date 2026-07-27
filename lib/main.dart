import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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

/// Shows a slim "you're offline" bar over the app when requests can't reach the
/// server, and hides it automatically once connectivity returns.
class _OfflineWrapper extends StatelessWidget {
  final Widget child;
  const _OfflineWrapper({required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ApiClient.instance.offline,
      builder: (context, offline, _) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              child,
              if (offline)
                Positioned(
                  left: 0, right: 0,
                  bottom: MediaQuery.of(context).padding.bottom + 8,
                  child: Center(
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2937),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 12, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 8),
                            Text('You\'re offline', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
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
                    child: _OfflineWrapper(child: child!),
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
