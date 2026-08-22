import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's theme mode (light / dark / system), persisted across launches.
class ThemeController extends ChangeNotifier {
  static const _key = 'app.themeMode';
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Effective dark state for a given platform brightness.
  bool isDark(Brightness platform) => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system => platform == Brightness.dark,
      };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    switch (p.getString(_key)) {
      case 'dark':
        _mode = ThemeMode.dark;
        break;
      case 'light':
        _mode = ThemeMode.light;
        break;
      default:
        _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> set(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_key, mode.name);
  }

  /// Convenience toggle used by a simple switch (system → resolves to opposite).
  void toggleDark(bool wantDark) => set(wantDark ? ThemeMode.dark : ThemeMode.light);
}

/// Exposes the [ThemeController] to the tree.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({super.key, required ThemeController controller, required super.child})
      : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found');
    return scope!.notifier!;
  }
}
