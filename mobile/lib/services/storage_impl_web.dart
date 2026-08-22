// Web implementation — browser localStorage.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

bool hasSeenOnboarding() {
  try {
    return html.window.localStorage['has_seen_onboarding'] == 'true';
  } catch (_) {
    return false;
  }
}

void markOnboardingSeen() {
  try {
    html.window.localStorage['has_seen_onboarding'] = 'true';
  } catch (_) {}
}
