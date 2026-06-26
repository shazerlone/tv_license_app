// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class StorageService {
  static bool hasSeenOnboarding() {
    try {
      return html.window.localStorage['has_seen_onboarding'] == 'true';
    } catch (_) {
      return false;
    }
  }

  static void markOnboardingSeen() {
    try {
      html.window.localStorage['has_seen_onboarding'] = 'true';
    } catch (_) {}
  }
}
