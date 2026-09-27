# DSA Mentor — Android app (Flutter)

The Android client for DSA Mentor. It talks to the same Node backend as the web
app (`../backend_DSA`) and uses the same accounts. The UI is the mobile
expression of the **Ember** brand — warm dark surfaces, gold accents, Fraunces
display type.

Verified working end-to-end on 2026-09-28: clean build, install, login against
a live `backend_DSA` instance, and the problem catalogue (714 problems) loads
correctly on a Pixel-class Android emulator.

## Feature parity with the web app

| Web feature | In the app |
|---|---|
| Login / session | ✅ JWT login, Keystore-stored token, automatic refresh via the captured refresh cookie |
| Practice: catalogue, search, filters | ✅ Problems tab |
| Problem page: statement, samples, hints | ✅ Progressive hints (one at a time) |
| Editor: run & submit | ✅ Run against samples, submit to the judge, per-test verdicts |
| Playground (run any code, stdin) | ✅ Playground tab — languages from `/playground/languages` |
| AI code explanation | ✅ "Explain this code" on the Playground |
| AI mentor chat | ✅ Mentor tab (`/chatbot/chat`) |
| Mock interviews | ✅ Full suite: setup (type/difficulty/duration/questions) → timed session with interviewer chat + code editor + run/submit/hint → end → written review (scores as bars + feedback sections) + history |
| Roadmaps | ✅ List, AI generation from a goal, phase/task detail, delete |
| Progress analytics | ✅ Progress screen: account stats, catalogue difficulty mix, interview stats |
| Achievements & badges | ✅ From `/achievements/user` with progress bars |
| Community resources | ✅ List + detail |
| Help center | ✅ Categories, search, article reader |
| Support tickets | ✅ Ticket list + new-ticket form |
| Theme switcher | ✅ Ember (dark) / Parchment (light) / system, persisted |
| Streak / accuracy / level | ✅ Home + Progress |
| Registration (email OTP) | Web-only for now — sign up there, then log in here |
| Admin console | Web-only by design (management surface) |
| Discussions, contests, leaderboards | Not in v1 |

## Requirements

| Tool | Version known to work | Notes |
|---|---|---|
| Flutter SDK | 3.47.5 (Dart 3.13.4) | `flutter --version` |
| JDK | 17–21 | **Not 25** — Gradle 8.14 cannot run on it (fails with a bare `25.0.4.1` error). Use a Temurin/Adoptium build if your system JDK is too new. |
| Gradle (wrapper) | 8.14+ | Pinned in `android/gradle/wrapper/gradle-wrapper.properties`; this Flutter SDK refuses to build under 8.14. |
| Android Gradle Plugin | 8.9.1 (project) | Below Flutter's preferred minimum (8.11.1) — harmless with the flag noted below, until AGP is bumped. |
| Android SDK | Platform 34, NDK (side-by-side) 28.2 | Auto-installed by the Gradle build on first run if missing. |

Check what Flutter can already see:

```bash
flutter doctor
flutter devices        # lists emulators/phones; `flutter emulators` lists AVDs
```

## One-time setup

This folder ships the Dart source and `pubspec.yaml`; the `android/` platform
folder is already generated and committed — **do not re-run `flutter create`**,
it's only needed if that folder is ever deleted.

1. **Point Flutter at a working JDK** (skip if `flutter doctor` already shows a
   green Java line for 17–21):

   ```bash
   # download once, anywhere outside the repo
   mkdir -p ~/.jdks && cd ~/.jdks
   curl -sL -o temurin21.tar.gz \
     "https://api.adoptium.net/v3/binary/latest/21/ga/linux/x64/jdk/hotspot/normal/eclipse?project=jdk"
   tar xzf temurin21.tar.gz && rm temurin21.tar.gz

   flutter config --jdk-dir="$HOME/.jdks/jdk-21*"   # expand the glob yourself
   ```

   If `~/.config/flutter/settings` already has a `jdk-dir` pointing at a path
   that no longer exists (e.g. left behind by another tool under `/tmp`),
   Gradle fails immediately with `JAVA_HOME is set to an invalid directory`
   — fix it the same way.

2. **Install dependencies:**

   ```bash
   flutter pub get
   ```

3. **Allow internet + your dev backend** (already set in this repo's
   `android/app/src/main/AndroidManifest.xml` — only needed again if that file
   is regenerated):

   ```xml
   <uses-permission android:name="android.permission.INTERNET" />
   ```

   and inside `<application …>`:

   ```xml
   android:usesCleartextTraffic="true"
   ```

   (the dev backend is plain HTTP; drop this once the app talks to an HTTPS
   server.)

4. **Point the app at your backend.** The default is the Android-emulator
   alias for your machine: `http://10.0.2.2:5000/api` (defined in
   `lib/core/config.dart`). For a **physical phone**, run instead:

   ```bash
   flutter run --dart-define=API_BASE_URL=http://<YOUR-LAN-IP>:5000/api
   ```

   (Phone and PC must share the Wi-Fi; find the PC IP with `ip addr`.)

## Run it (debug, on an emulator or phone)

```bash
# terminal 1 — the backend
cd ../backend_DSA && npm start          # listens on 0.0.0.0:5000

# terminal 2 — an emulator, if you don't have a phone plugged in
flutter emulators --launch <emulator-id>     # e.g. dsa_pixel; `flutter emulators` lists them

# terminal 3 — the app
flutter run -d <device-id>              # `flutter devices` lists ids
```

If AGP is still below Flutter's minimum (see Requirements table), add:

```bash
flutter run -d <device-id> --android-skip-build-dependency-validation
```

Sign in with any account that already exists on the web app.

## Build

```bash
# Debug APK (same as `flutter run` produces, without attaching a debugger)
flutter build apk --debug --android-skip-build-dependency-validation

# Release APK — unsigned unless android/key.properties + signing config are set up
flutter build apk --release --android-skip-build-dependency-validation

# Play Store bundle
flutter build appbundle --release --android-skip-build-dependency-validation
```

Output lands under `build/app/outputs/flutter-apk/` (APK) or
`build/app/outputs/bundle/release/` (AAB). Drop the
`--android-skip-build-dependency-validation` flag once AGP is bumped to 8.11.1+
(see Troubleshooting).

Run the test suite before shipping a build:

```bash
flutter analyze     # static analysis — should report 0 errors
flutter test        # widget/unit tests
```

## Troubleshooting

- **`JAVA_HOME is set to an invalid directory`** — Flutter's own saved
  `jdk-dir` (in `~/.config/flutter/settings`) points somewhere that no longer
  exists. Re-run `flutter config --jdk-dir=<path>` with a real JDK 17–21.
- **Gradle fails with a bare version number as the error (e.g. `25.0.4.1`)** —
  the active JDK is too new for the Gradle version in
  `gradle-wrapper.properties`. Switch to JDK 21 (see One-time setup step 1).
- **`Your project's Gradle version (…) is lower than Flutter's minimum
  supported version`** — bump `distributionUrl` in
  `android/gradle/wrapper/gradle-wrapper.properties` to the version the error
  names, or pass `--android-skip-build-dependency-validation`.
- **`Your project's Android Gradle Plugin version (8.9.1) is lower than
  Flutter's minimum supported version`** — pass
  `--android-skip-build-dependency-validation` (used throughout this doc) or
  bump the AGP version in `android/settings.gradle.kts`. AGP 9+ reads a
  different Gradle DSL and will need the project's `build.gradle.kts` files
  updated too — don't jump straight to 9.x without testing.
- **App shows the login screen but nothing loads / "No connection to the
  server"** — the backend isn't running, or an emulator can't reach
  `10.0.2.2` (only works from an Android *emulator*, not a physical phone or
  desktop browser). Confirm with `curl http://localhost:5000/api/health` on
  the host first.
- **Blank/white frame after launch** — usually a Dart compile error masked by
  a stale build. Run `flutter analyze` first; it reports the same errors much
  faster than a full Gradle build.

## Project layout

```
lib/
├── main.dart                     app entry, providers, theme wiring
├── core/
│   ├── config.dart               API base URL (dart-define override)
│   ├── theme.dart                Ember + Parchment ThemeData
│   ├── token_store.dart          secure storage for tokens / refresh cookie
│   └── api_client.dart           http client: bearer, envelope, refresh-on-401
├── models/
│   ├── models.dart               User, Problem, Stats, RunResult
│   └── content.dart              chat, playground, interview, roadmap,
│                                 achievements, help, tickets, resources
├── services/
│   ├── services.dart             AuthService, ProblemService
│   └── feature_services.dart     Mentor, Playground, Interview, Roadmap,
│                                 Achievements, Help, Resources, Support, Dashboard
├── state/app_state.dart          AuthController, ThemeController, shell tabs
├── screens/
│   ├── splash / login            session restore + sign-in
│   ├── main_shell.dart           5 tabs: Home · Practice · Playground · Mentor · More
│   ├── home_screen.dart          stats + quick actions
│   ├── problems_screen.dart      catalogue with search + filters
│   ├── problem_detail_screen.dart statement, hints, editor, run/submit
│   ├── playground_screen.dart    free code runner + AI explain
│   ├── mentor_screen.dart        AI mentor chat
│   ├── interview_screens.dart    dashboard, setup, timed session, review
│   ├── roadmaps_screen.dart      list, generator, phase detail
│   ├── achievements_screen.dart  badges + progress analytics screen
│   ├── content_screens.dart      resources, help center, support tickets
│   ├── more_screen.dart          feature hub grid
│   └── profile_screen.dart       account card, theme, sign out
└── widgets/                      brand mark, badges, stat cards, code pane
```
# app_DSA
