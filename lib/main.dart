import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'state/session.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
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

  @override
  void dispose() {
    _session.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _session,
      child: AppStateScope(
        controller: _appState,
        child: MaterialApp(
          title: 'millimore',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme,
          // Keep the layout compact and consistent regardless of the device's
          // OS font-size setting: clamp text scaling to a tight range so the UI
          // never balloons ("zoomed") or collapses on any phone.
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.05),
              ),
              child: child!,
            );
          },
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
