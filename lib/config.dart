/// Development & environment flags for millimore.
///
/// While [kDevMode] is true, the splash screen and onboarding flow are shown
/// on every launch so design work is always visible during development.
/// Flip this to false before shipping to production.
const bool kDevMode = true;

/// When true, the app talks to the live backend (see docs/BACKEND_CONTRACT.md)
/// instead of the local demo store.
const bool kUseBackend = true;

/// Base URL of the Millimore backend API (no trailing slash).
/// Primary is now the AWS (ECS) backend; the old Render URL still works as a
/// fallback. Override for a local backend with
/// --dart-define=API_BASE_URL=http://localhost:3000/v1
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://mi-41bae9db1d7c40e2846cc32d8ac9f51f.ecs.us-west-2.on.aws/v1',
);

/// WebSocket base (same host, wss). Used when realtime (prices/portfolio/live)
/// is wired. Derived from [kApiBaseUrl] so a --dart-define override applies too.
String get kWsBaseUrl => kApiBaseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://') + '/ws';

/// Build identity, stamped by Codemagic (--dart-define=BUILD_SHA=$CM_COMMIT).
/// Shown on the login screen so we can always tell which build is on a device.
const String kBuildSha = String.fromEnvironment('BUILD_SHA', defaultValue: 'local-dev');
const String kBuildBranch = String.fromEnvironment('BUILD_BRANCH', defaultValue: '');

String get kBuildLabel {
  final sha = kBuildSha.length > 7 ? kBuildSha.substring(0, 7) : kBuildSha;
  return kBuildBranch.isEmpty ? 'build $sha' : 'build $sha · $kBuildBranch';
}
