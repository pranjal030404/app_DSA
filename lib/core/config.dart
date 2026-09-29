/// Environment configuration for the DSA Mentor Android client.
///
/// This is the ONLY place the backend URL is defined — every screen, service
/// and the API client import [kApiBaseUrl] from here rather than hardcoding
/// a host anywhere else. To point the whole app at a different backend
/// (dev → staging → production), change ONE line: the `defaultValue` below.
///
///   defaultValue: 'http://10.0.2.2:5000/api',   // ← change this string
///
///  • Android emulator (default) → 10.0.2.2 is the host machine's loopback.
///  • Physical device on the same Wi-Fi → your host's LAN IP, e.g.
///                                        'http://192.168.1.20:5000/api'
///  • Going live → your real domain, e.g. 'https://api.dsa.example.com/api'
///                 (also flip `android:usesCleartextTraffic` to "false" in
///                 android/app/src/main/AndroidManifest.xml once this is
///                 HTTPS — it's only "true" to allow the dev backend's HTTP).
///
/// This can also be overridden per-build without editing the file, via
/// `flutter run --dart-define=API_BASE_URL=https://api.dsa.example.com/api`
/// — useful for a one-off build without touching source, but editing the
/// line above is the "just change one thing and it's live everywhere" path.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://dsa.arthvex.co.in/api',
);

/// Seconds before an HTTP call gives up.
const Duration kHttpTimeout = Duration(seconds: 20);
