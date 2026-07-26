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
/// IMPORTANT: this must include the API path prefix the backend actually uses.
/// If your backend serves endpoints at the root (e.g. /auth/login) instead of
/// /v1/auth/login, remove the '/v1' below.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://millimore-backend.onrender.com/v1',
);

/// Build identity, stamped by Codemagic (--dart-define=BUILD_SHA=$CM_COMMIT).
/// Shown on the login screen so we can always tell which build is on a device.
const String kBuildSha = String.fromEnvironment('BUILD_SHA', defaultValue: 'local-dev');
const String kBuildBranch = String.fromEnvironment('BUILD_BRANCH', defaultValue: '');

String get kBuildLabel {
  final sha = kBuildSha.length > 7 ? kBuildSha.substring(0, 7) : kBuildSha;
  return kBuildBranch.isEmpty ? 'build $sha' : 'build $sha · $kBuildBranch';
}
