import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'state/session.dart';

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

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: _session,
      child: MaterialApp(
        title: 'millimore',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const SplashScreen(),
      ),
    );
  }
}
