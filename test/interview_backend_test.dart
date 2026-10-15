// Integration test: the REAL Android InterviewService against a REAL running
// backend. It is skipped unless the app was built against localhost, because
// the default API base URL is production.
//
//   flutter test test/interview_backend_test.dart \
//     --dart-define=API_BASE_URL=http://localhost:5055/api \
//     --dart-define=E2E_EMAIL=e2e.learner@example.com --dart-define=E2E_PASSWORD=Passw0rd!x
//
// Needs the disposable e2e database (backend_DSA/scripts/seedInterviewE2E.js).
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_mentor/core/api_client.dart';
import 'package:dsa_mentor/core/config.dart';
import 'package:dsa_mentor/core/token_store.dart';
import 'package:dsa_mentor/models/interview_mode.dart';
import 'package:dsa_mentor/services/feature_services.dart';

class _MemoryTokens extends TokenStore {
  String? access;
  String? refresh;
  @override
  Future<String?> readAccess() async => access;
  @override
  Future<void> writeAccess(String token) async => access = token;
  @override
  Future<String?> readRefreshCookie() async => refresh;
  @override
  Future<void> writeRefreshCookie(String cookiePair) async => refresh = cookiePair;
  @override
  Future<void> clearSession() async {
    access = null;
    refresh = null;
  }
}

const _email = String.fromEnvironment('E2E_EMAIL', defaultValue: 'e2e.learner@example.com');
const _password = String.fromEnvironment('E2E_PASSWORD', defaultValue: 'Passw0rd!x');
final _local = RegExp(r'^http://(localhost|127\.0\.0\.1)[:/]').hasMatch(kApiBaseUrl);

const _solutions = {
  'Add Two Numbers': "const [a,b]=require('fs').readFileSync(0,'utf8').trim().split(/\\s+/).map(Number);console.log(a+b);",
  'Max of Two': "const [a,b]=require('fs').readFileSync(0,'utf8').trim().split(/\\s+/).map(Number);console.log(Math.max(a,b));",
};

void main() {
  test('interview flow through the Android service layer', () async {
    final tokens = _MemoryTokens();
    final api = ApiClient(tokens);
    final login = await api.post('/auth/login', body: {'email': _email, 'password': _password});
    tokens.access = (login['data']['accessToken'] as String);
    final svc = InterviewService(api);

    // create -> session (the screens parse these top-level bodies)
    final id = await svc.create(interviewType: 'mock', difficulty: 'easy', durationMinutes: 30, questionCount: 2);
    expect(id, isNotEmpty);
    var session = await svc.session(id);
    expect(session.id, id);
    expect(session.status, 'in-progress');
    // Only the current question is sent; the total comes separately and later questions arrive one at a time.
    expect(session.questions.length, 1);
    expect(session.totalQuestions, 2);
    expect(session.timeRemaining, greaterThan(0));

    // chat: a retried send (same id) must return the same reply and create ONE turn
    const msgId = 'android-test-msg-1';
    final r1 = await svc.sendMessage(id, 'I would use a hash map', clientMessageId: msgId);
    final r2 = await svc.sendMessage(id, 'I would use a hash map', clientMessageId: msgId);
    expect(r1, isNotEmpty);
    expect(r2, r1);
    session = await svc.session(id);
    expect(session.messages.where((m) => m['role'] == 'user').length, 1);
    expect(session.messages.where((m) => m['role'] == 'ai').length, 1);

    // hint is persisted and survives a reload
    final hint = await svc.hint(id);
    expect(hint, isNotEmpty);
    session = await svc.session(id);
    expect(session.messages.where((m) => m['kind'] == 'hint').length, 2);

    // pause freezes, resume restarts; chat is refused while paused
    final paused = await svc.pause(id);
    expect(paused.status, 'paused');
    expect((await svc.session(id)).status, 'paused');
    await expectLater(
      svc.sendMessage(id, 'while paused'),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
    final resumed = await svc.resume(id);
    expect(resumed.status, 'in-progress');
    expect(resumed.timeRemaining, greaterThan(0));

    // real sandbox: a wrong run fails, the right answer passes and submit advances
    final title = session.questions[session.currentIndex].title;
    final bad = await svc.run(id, 'console.log(0)', 'javascript');
    expect(bad.passedTests, lessThan(bad.totalTests));
    final good = await svc.submit(id, _solutions[title]!, 'javascript');
    expect(good.passedTests, good.totalTests);
    expect(good.hasNextQuestion, isTrue);
    expect(good.nextQuestion, isNotNull); // the question the server will actually grade next
    final next = good.nextQuestion!['title'] as String;
    final last = await svc.submit(id, _solutions[next]!, 'javascript');
    expect(last.hasNextQuestion, isFalse);

    // end + results: inner map, objective facts and a rubric status the screen polls on
    await svc.end(id);
    final results = await svc.results(id);
    expect(results['overallScore'], isA<num>());
    expect(results.containsKey('rubricStatus'), isTrue);
    expect(['pending', 'done', 'unavailable'], contains(results['rubricStatus']));
    expect((results['questions'] as List).first['testsTotal'], isNotNull);
    // hidden tests never reach the app
    expect(results.toString().contains('hiddenTestCases'), isFalse);

    // history lists the finished interview
    final history = await svc.history();
    expect(history.any((h) => h.toString().isNotEmpty), isTrue);
    expect(history, isNotEmpty);
  }, skip: _local ? false : 'set --dart-define=API_BASE_URL=http://localhost:<port>/api to run (default is production)');

  test('AI interview modes through the Android service layer: technical, job, DSA, diagram, coding hold, results', () async {
    final tokens = _MemoryTokens();
    final api = ApiClient(tokens);
    final login = await api.post('/auth/login', body: {'email': _email, 'password': _password});
    tokens.access = (login['data']['accessToken'] as String);
    final svc = InterviewService(api);

    // Catalog for the wizard.
    final cat = await svc.catalog();
    expect(cat.presets.any((p) => p.id == 'campus'), isTrue);
    expect(cat.tracks.any((t) => t.id == 'system-design'), isTrue);

    // Technical interview: conversational, never a code workspace.
    final (techId, _) = await svc.createInterview({'track': 'general', 'interviewMode': 'technical_interview', 'interviewType': 'mock', 'format': 'technical', 'questionCount': 2, 'duration': 20});
    var s = await svc.session(techId);
    expect(s.interviewMode, 'technical_interview');
    expect(roomKind(interviewMode: s.interviewMode, track: s.track), 'conversational');
    expect(s.openQuestion!.starterCode, isEmpty);
    expect(s.openQuestion!.examples, isEmpty);
    final turn = await svc.sendTurn(techId, 'A process has its own address space; threads share memory inside one process, so they need locks.', clientMessageId: 'android-modes-1');
    expect((turn['response'] as String).isNotEmpty, isTrue);
    final ans = await svc.answer(techId, s.currentIndex);
    expect(ans['hasNextQuestion'], isTrue);
    s = await svc.session(techId);
    expect(s.currentIndex, 1);
    await svc.end(techId);
    final tr = await svc.results(techId);
    expect(tr['interviewMode'], 'technical_interview');
    expect(tr['report'], isA<Map>());

    // Job interview mode is its own kind.
    final (jobId, _) = await svc.createInterview({'track': 'general', 'interviewMode': 'job_interview', 'interviewType': 'mock', 'format': 'behavioral', 'questionCount': 2, 'duration': 20});
    expect((await svc.session(jobId)).interviewMode, 'job_interview');
    await svc.end(jobId);

    // A contradictory mode is refused with its code.
    await expectLater(
      svc.createInterview({'track': 'general', 'interviewMode': 'dsa_interview', 'interviewType': 'mock'}),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'INTERVIEW_MODE_TRACK_MISMATCH')),
    );

    // DSA interview keeps its editor data.
    final (dsaId, _) = await svc.createInterview({'track': 'dsa', 'interviewMode': 'dsa_interview', 'interviewType': 'conversational', 'difficulty': 'easy', 'questionCount': 1, 'duration': 30, 'topics': []});
    final ds = await svc.session(dsaId);
    expect(ds.interviewMode, 'dsa_interview');
    expect(roomKind(interviewMode: ds.interviewMode, track: ds.track), 'dsa');
    expect(ds.openQuestion!.examples, isNotEmpty);
    await svc.end(dsaId);

    // System-design diagram: saved, restored, graded as text.
    final (sdId, _) = await svc.createInterview({'track': 'general', 'trackId': 'system-design', 'interviewType': 'mock', 'experience': 'senior'});
    var sd = await svc.session(sdId);
    expect(sd.openQuestion!.kind, 'system-design');
    final scene = DiagramScene()..addNode('Web client', 'client')..addNode('API service', 'service');
    scene.addEdge('n1', 'n2', 'HTTPS');
    final saved = await svc.saveDiagram(sdId, sd.currentIndex, scene.toMap());
    expect((saved!['nodes'] as List).length, 2);
    sd = await svc.session(sdId);
    expect(DiagramScene.fromMap(sd.currentDiagram).toText(), scene.toText());
    await svc.answer(sdId, sd.currentIndex);
    await svc.end(sdId);
    final sdr = await svc.results(sdId);
    expect((sdr['questions'] as List).first['answer'], contains('Diagram components: Web client (client), API service (service)'));
    expect((sdr['questions'] as List).first['diagram'], isA<Map>());

    // Coding round between rounds, with an enforced round timer.
    final (gid, _) = await svc.createInterview({
      'track': 'general', 'interviewType': 'mock', 'preset': 'campus', 'enforceRoundTimers': true,
      'codingRound': {'questionCount': 1, 'duration': 20, 'difficulty': 'easy', 'afterRoundKey': 'technical'},
    });
    var g = await svc.session(gid);
    expect(g.roundTimerEnforced, isTrue);
    expect(g.roundSecondsRemaining, greaterThan(0));
    final r0 = g.rounds.first;
    Map<String, dynamic> last = {};
    for (var i = 0; i < r0.count; i++) {
      last = await svc.answer(gid, i, skip: true);
    }
    expect((last['hold'] as Map)['for'], 'coding');
    g = await svc.session(gid);
    expect(g.holdFor, 'coding');
    expect(g.openQuestion!.description, isEmpty); // the waiting question is not disclosed
    await expectLater(svc.resume(gid), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'CODING_ROUND_PENDING')));
    final (cid, _) = await svc.startCodingRound(gid);
    final cs = await svc.session(cid);
    expect(cs.interviewMode, 'dsa_interview');
    await svc.end(cid);
    final cr = await svc.results(cid);
    expect((cr['loop'] as Map)['generalOpen'], isTrue);
    g = await svc.session(gid);
    expect(g.holdFor, isNull);
    expect(g.status, 'in-progress');
    expect(g.currentIndex, r0.start + r0.count);
    expect(g.messages.last['content'], contains('Welcome back from the coding round'));
    await svc.end(gid);

    // Dashboard data: the active session list and history carry the mode.
    final history = await svc.history();
    expect(history.any((h) => h.interviewMode == 'technical_interview'), isTrue);
  }, skip: _local ? false : 'set --dart-define=API_BASE_URL=http://localhost:<port>/api to run (default is production)');
}
