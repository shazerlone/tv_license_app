/// Development & environment flags for millimore.
///
/// While [kDevMode] is true, the splash screen and onboarding flow are shown
/// on every launch so design work is always visible during development.
/// Flip this to false before shipping to production.
const bool kDevMode = true;

/// When true, the app talks to the live backend (see docs/BACKEND_CONTRACT.md)
/// instead of the local demo store. Flip to true once your backend is deployed.
const bool kUseBackend = false;

/// Base URL of the Millimore backend API (no trailing slash).
/// Example: https://api.millimore.app/v1  or  http://192.168.1.5:3000/v1 for local.
const String kApiBaseUrl = 'https://api.millimore.app/v1';
