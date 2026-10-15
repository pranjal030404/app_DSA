// On-device end-to-end test of the AI interview, run on an Android emulator against a LOCAL backend:
//
//   flutter test integration_test/ai_interview_test.dart -d emulator-5554 \
//     --dart-define=API_BASE_URL=http://10.0.2.2:5055/api
//
// Needs the disposable e2e database (backend_DSA/scripts/seedInterviewE2E.js) and its fixed test account.
// It never runs against production: it refuses any base URL that is not the emulator's host alias.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:dsa_mentor/core/config.dart';
import 'package:dsa_mentor/main.dart' as app;
import 'package:dsa_mentor/screens/interview_room.dart';

const _email = String.fromEnvironment('E2E_EMAIL', defaultValue: 'e2e.learner@example.com');
const _password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'Passw0rd!x');

Future<void> pumpUntil(WidgetTester t, Finder f, {Duration timeout = const Duration(seconds: 40)}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for $f');
}

Future<void> tapVisible(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pump(const Duration(milliseconds: 300));
  await t.tap(f);
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AI interview on a real Android device: technical room, voice/camera controls, results, DSA editor', (t) async {
    expect(kApiBaseUrl.startsWith('http://10.0.2.2:'), isTrue, reason: 'only for a local backend reached from the emulator');
    app.main();

    // Landing -> sign in (a previous run may still be signed in).
    final startEnd = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(startEnd) && find.text('Sign in').evaluate().isEmpty && find.text('AI interviews').evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 250));
    }
    if (find.text('Sign in').evaluate().isNotEmpty) {
      await t.tap(find.text('Sign in').first);
      await pumpUntil(t, find.widgetWithText(TextFormField, 'Email'));
      await t.enterText(find.widgetWithText(TextFormField, 'Email'), _email);
      await t.enterText(find.widgetWithText(TextFormField, 'Password'), _password);
      await t.tap(find.widgetWithText(FilledButton, 'Sign in'));
    }
    await pumpUntil(t, find.text('AI interviews'));
    // ignore: avoid_print
    print('STEP 01-home');

    // Interviews -> Technical interview -> start.
    await tapVisible(t, find.text('AI interviews').first);
    await pumpUntil(t, find.byKey(const Key('start-technical_interview')));
    // ignore: avoid_print
    print('STEP 02-dashboard');
    await t.tap(find.byKey(const Key('start-technical_interview')));
    await pumpUntil(t, find.byKey(const Key('start-interview')));
    await tapVisible(t, find.byKey(const Key('start-interview')));
    await pumpUntil(t, find.byType(ConversationalRoom));
    await pumpUntil(t, find.byKey(const Key('answer-box')));
    // ignore: avoid_print
    print('STEP 03-technical-room');

    // The technical room has no code workspace.
    expect(find.text('Code'), findsNothing);
    expect(find.text('Run'), findsNothing);
    expect(find.text('Submit'), findsNothing);
    expect(find.text('Technical interview'), findsOneWidget);

    // Answer by typing: exactly one reply comes back.
    final before = find.byKey(const Key('ai-message')).evaluate().length;
    await t.enterText(find.byKey(const Key('answer-box')), 'A process has its own address space while threads share memory inside one process, so threads need locks for shared data.');
    await t.pump();
    await t.tap(find.byKey(const Key('send')));
    final end = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(end) && find.byKey(const Key('ai-message')).evaluate().length <= before) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.byKey(const Key('ai-message')).evaluate().length, greaterThan(before));
    expect(find.text('A process has its own address space while threads share memory inside one process, so threads need locks for shared data.'), findsOneWidget);

    // Camera: off until asked; on shows the emulator's camera (permission granted by the runner) or an explanation.
    await tapVisible(t, find.byTooltip('Turn camera on'));
    final camEnd = DateTime.now().add(const Duration(seconds: 15));
    while (DateTime.now().isBefore(camEnd) &&
        find.byTooltip('Turn camera off').evaluate().isEmpty &&
        find.textContaining('Camera access was denied').evaluate().isEmpty &&
        find.textContaining('No camera is available').evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 300));
    }
    final cameraOn = find.byTooltip('Turn camera off').evaluate().isNotEmpty;
    // ignore: avoid_print
    print('CAMERA: ${cameraOn ? 'live preview shown' : 'explained as unavailable/denied'}');
    expect(cameraOn || find.textContaining('Camera access was denied').evaluate().isNotEmpty || find.textContaining('No camera is available').evaluate().isNotEmpty, isTrue);
    // ignore: avoid_print
    print('STEP 04-camera');
    if (cameraOn) await tapVisible(t, find.byTooltip('Turn camera off'));

    // Mic: either listening, or a clear reason (emulators often have no speech recogniser).
    await tapVisible(t, find.byTooltip('Answer by voice'));
    await t.pump(const Duration(seconds: 3));
    final listening = find.byTooltip('Stop microphone').evaluate().isNotEmpty;
    final explained = find.textContaining('Speech recognition').evaluate().isNotEmpty || find.textContaining('Microphone').evaluate().isNotEmpty || find.textContaining('Voice input').evaluate().isNotEmpty || find.textContaining("didn't").evaluate().isNotEmpty;
    // ignore: avoid_print
    print('MIC: ${listening ? 'listening' : explained ? 'explained as unavailable' : 'no state change'}');
    if (listening) await tapVisible(t, find.byTooltip('Stop microphone'));
    expect(listening || explained, isTrue);

    // Pause freezes the clock; resume restarts it.
    await tapVisible(t, find.byTooltip('Pause interview'));
    await pumpUntil(t, find.byTooltip('Resume interview'));
    final p1 = (t.widget<Text>(find.byKey(const Key('room-timer')))).data;
    await t.pump(const Duration(seconds: 3));
    expect((t.widget<Text>(find.byKey(const Key('room-timer')))).data, p1);
    await tapVisible(t, find.byTooltip('Resume interview'));
    await pumpUntil(t, find.byTooltip('Pause interview'));

    // End -> results with the evidence report.
    await t.tap(find.text('End'));
    await pumpUntil(t, find.text('End interview'));
    await t.tap(find.text('End interview'));
    await pumpUntil(t, find.byKey(const Key('overall-score')), timeout: const Duration(seconds: 60));
    // ignore: avoid_print
    print('STEP 05-results');
    expect(find.textContaining('Technical interview results'), findsOneWidget);

    // Back to the dashboard -> DSA interview: problem + editor + run.
    await t.pageBack();
    await pumpUntil(t, find.byKey(const Key('start-dsa_interview')));
    await t.tap(find.byKey(const Key('start-dsa_interview')));
    await pumpUntil(t, find.byKey(const Key('start-interview')));
    await tapVisible(t, find.byKey(const Key('start-interview')));
    await pumpUntil(t, find.text('Code'));
    expect(find.byType(ConversationalRoom), findsNothing);
    await t.tap(find.text('Code'));
    await pumpUntil(t, find.text('Run'));
    expect(find.byKey(const Key('problem-panel')), findsOneWidget);
    // ignore: avoid_print
    print('STEP 06-dsa-editor');
    await t.enterText(find.byType(TextField).last, 'console.log(0)');
    await t.tap(find.text('Run'));
    final runEnd = DateTime.now().add(const Duration(seconds: 40));
    while (DateTime.now().isBefore(runEnd) && find.textContaining('Run:').evaluate().isEmpty && find.textContaining("Couldn't run").evaluate().isEmpty) {
      await t.pump(const Duration(milliseconds: 300));
    }
    // ignore: avoid_print
    print('RUN: ${find.textContaining('Run:').evaluate().isNotEmpty ? 'judged' : 'runner unavailable (explained)'}');
    expect(find.textContaining('Run:').evaluate().isNotEmpty || find.textContaining("Couldn't run").evaluate().isNotEmpty, isTrue);
    // ignore: avoid_print
    print('STEP 07-dsa-run');
  });
}
