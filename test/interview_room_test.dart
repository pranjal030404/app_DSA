// Widget tests: mode routing, the conversational room, the setup wizard payloads and the new results report.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dsa_mentor/core/api_client.dart';
import 'package:dsa_mentor/core/theme.dart';
import 'package:dsa_mentor/core/token_store.dart';
import 'package:dsa_mentor/models/content.dart';
import 'package:dsa_mentor/models/interview_mode.dart';
import 'package:dsa_mentor/screens/interview_room.dart';
import 'package:dsa_mentor/screens/interview_screens.dart';
import 'package:dsa_mentor/services/feature_services.dart';
import 'package:dsa_mentor/services/interview_voice.dart';

class FakeVoice extends InterviewVoice {
  FakeVoice() : super();
  final spoken = <String>[];
  @override
  Future<void> initSpeaker() async => ttsAvailable = true;
  @override
  Future<void> speak(String text) async => spoken.add(text);
  @override
  Future<void> stopSpeaking() async {}
  @override
  Future<void> startListening(void Function(String text) onText) async {
    listening = true;
    onText('spoken answer');
    notifyListeners();
  }

  @override
  Future<void> stopListening() async {
    listening = false;
    notifyListeners();
  }
}

class RoomService extends InterviewService {
  RoomService() : super(ApiClient(TokenStore()));

  String mode = 'technical_interview';
  String? track = 'general';
  String status = 'in-progress';
  String? holdFor;
  int? roundSeconds;
  String kind = 'conceptual';
  int sessionCalls = 0;
  final turns = <String>[];
  final answers = <(int, bool)>[];
  Map<String, dynamic>? savedScene;
  Map<String, dynamic>? createdWith;
  Map<String, dynamic>? advanceOnNextTurn;
  bool codingStarted = false, codingSkipped = false;
  Map<String, dynamic> resultsBody = {};

  @override
  Future<InterviewSession> session(String sessionId) async {
    sessionCalls++;
    return InterviewSession.fromMap({
      'session': {
        '_id': sessionId,
        'status': status,
        'interviewMode': mode,
        'track': track,
        'mode': 'coaching',
        'duration': 30,
        'timeRemaining': 1500,
        'currentQuestionIndex': 0,
        'totalQuestions': 3,
        'rounds': [
          {'key': 'technical', 'label': 'Core technical knowledge', 'minutes': 10, 'start': 0, 'count': 2},
          {'key': 'hr', 'label': 'HR and career', 'minutes': 5, 'start': 2, 'count': 1},
        ],
        if (roundSeconds != null) 'roundTimer': {'enforced': true, 'secondsRemaining': roundSeconds, 'finished': false},
        if (holdFor != null) 'hold': {'for': holdFor, 'coding': {'questionCount': 1, 'duration': 20}},
        'currentQuestion': {
          '_id': 'q1',
          'title': mode == 'dsa_interview' ? 'Two Sum' : 'Processes vs threads',
          'description': mode == 'dsa_interview' ? 'Find two numbers.' : 'Explain processes vs threads.',
          'kind': mode == 'dsa_interview' ? 'coding' : kind,
          'examples': mode == 'dsa_interview' ? [{'input': '1 2', 'output': '3'}] : [],
          if (mode == 'dsa_interview') 'starterCode': {'python': '# start here'},
        },
        'questions': [
          {'_id': 'q1', 'title': 'Two Sum', 'description': 'Find two numbers.'}
        ],
        'messages': [
          {'role': 'ai', 'content': 'Question 1 of 3: Explain processes vs threads.', 'kind': 'chat', 'qi': 0},
        ],
      }
    });
  }

  @override
  Future<Map<String, dynamic>> sendTurn(String sessionId, String message, {String? code, String? clientMessageId}) async {
    turns.add(message);
    final adv = advanceOnNextTurn;
    advanceOnNextTurn = null;
    return {'success': true, 'response': 'Good. What about context switches?', if (adv != null) 'advance': adv};
  }

  @override
  Future<Map<String, dynamic>> answer(String sessionId, int questionIndex, {bool skip = false}) async {
    answers.add((questionIndex, skip));
    return {
      'success': true,
      'hasNextQuestion': true,
      'nextQuestionIndex': questionIndex + 1,
      'nextQuestion': {'_id': 'q2', 'title': 'Indexes', 'description': 'What does a database index cost?', 'kind': 'conceptual'},
      'openingMessage': 'Question 2 of 3: What does a database index cost?',
      'roundSecondsRemaining': 300,
    };
  }

  @override
  Future<Map<String, dynamic>?> saveDiagram(String sessionId, int questionIndex, Map<String, dynamic>? scene) async {
    savedScene = scene;
    return scene;
  }

  @override
  Future<(String, String?)> startCodingRound(String sessionId) async {
    codingStarted = true;
    return ('coding1', null);
  }

  @override
  Future<void> skipCodingRound(String sessionId) async {
    codingSkipped = true;
    holdFor = null;
    status = 'in-progress';
  }

  @override
  Future<InterviewCatalog> catalog() async => InterviewCatalog.fromMap({
        'presets': [
          {
            'id': 'campus',
            'label': 'Campus placement',
            'track': 'swe',
            'experience': 'student',
            'rounds': [
              {'key': 'technical', 'label': 'Core technical knowledge', 'count': 3, 'minutes': 15},
              {'key': 'behavioral', 'label': 'Behavioral', 'count': 1, 'minutes': 7},
              {'key': 'hr', 'label': 'HR and career', 'count': 2, 'minutes': 8},
            ]
          }
        ],
        'tracks': [],
        'experienceLevels': [
          {'id': 'student', 'label': 'Student', 'difficulty': 'easy'},
          {'id': 'fresher', 'label': 'Fresher', 'difficulty': 'easy'}
        ],
      });

  @override
  Future<(String, String?)> createInterview(Map<String, dynamic> body) async {
    createdWith = body;
    throw ApiException('stop here'); // keep the test on the setup screen
  }

  @override
  Future<Map<String, dynamic>> results(String sessionId) async => resultsBody;
}

Widget _app(RoomService svc, Widget home) =>
    MaterialApp(theme: buildAppTheme(ThemeSpec.auroraDark), home: Provider<InterviewService>.value(value: svc, child: home));

/// A tall phone-shaped surface: the room's list only builds what is on screen.
void _phone(WidgetTester t) {
  t.view.physicalSize = const Size(1080, 4000);
  t.view.devicePixelRatio = 2.0;
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('mode routing', () {
    testWidgets('a technical session opens the conversational room: no editor, no Run/Submit, no Code tab', (t) async {
      _phone(t);
      final svc = RoomService();
      await t.pumpWidget(_app(svc, const InterviewSessionScreen(sessionId: 's1')));
      await _settle(t);
      expect(find.byType(ConversationalRoom), findsOneWidget);
      expect(find.text('Technical interview'), findsOneWidget);
      expect(find.text('Code'), findsNothing);
      expect(find.text('Run'), findsNothing);
      expect(find.text('Submit'), findsNothing);
      expect(find.textContaining('Explain processes vs threads.'), findsWidgets);
    });

    testWidgets('a DSA session opens the problem + editor workspace', (t) async {
      _phone(t);
      final svc = RoomService()..mode = 'dsa_interview'..track = 'dsa';
      await t.pumpWidget(_app(svc, const InterviewSessionScreen(sessionId: 's1')));
      await _settle(t);
      expect(find.byType(ConversationalRoom), findsNothing);
      expect(find.text('Code'), findsOneWidget);
      await t.tap(find.text('Code'));
      await t.pumpAndSettle();
      expect(find.text('Run'), findsOneWidget);
      expect(find.text('Submit'), findsOneWidget);
      expect(find.byKey(const Key('problem-panel')), findsOneWidget);
    });

    testWidgets('an unrecognised mode never opens the editor', (t) async {
      _phone(t);
      final svc = RoomService()..mode = 'something_new'..track = 'dsa';
      await t.pumpWidget(_app(svc, const InterviewSessionScreen(sessionId: 's1')));
      await _settle(t);
      expect(find.byType(ConversationalRoom), findsOneWidget);
    });
  });

  group('conversational room', () {
    Future<(RoomService, FakeVoice)> open(WidgetTester t, {RoomService? s}) async {
      final svc = s ?? RoomService();
      final voice = FakeVoice();
      final initial = await svc.session('s1');
      await t.pumpWidget(_app(svc, ConversationalRoom(sessionId: 's1', initial: initial, voice: voice)));
      await _settle(t);
      return (svc, voice);
    }

    testWidgets('empty answers are not sent; an answer gets one reply, in order, and is spoken when enabled', (t) async {
      _phone(t);
      final (svc, voice) = await open(t);
      final send = find.byKey(const Key('send'));
      expect(t.widget<IconButton>(send).onPressed, isNull, reason: 'Send is disabled for an empty answer');
      voice.setSpeakReplies(true);
      await t.enterText(find.byKey(const Key('answer-box')), 'A process has its own memory.');
      await t.pump();
      await t.tap(send);
      await _settle(t);
      expect(svc.turns, ['A process has its own memory.']);
      final texts = t.widgetList<Text>(find.byKey(const Key('ai-message'))).map((w) => w.data).toList();
      expect(texts.last, 'Good. What about context switches?');
      expect(find.text('A process has its own memory.'), findsOneWidget);
      expect(voice.spoken, contains('Good. What about context switches?'));
    });

    testWidgets('voice fills the answer box for editing; nothing is sent until Send', (t) async {
      _phone(t);
      final (svc, _) = await open(t);
      await t.tap(find.byTooltip('Answer by voice'));
      await t.pump();
      expect(t.widget<TextField>(find.byKey(const Key('answer-box'))).controller!.text, 'spoken answer');
      expect(svc.turns, isEmpty);
    });

    testWidgets('Next needs an answer; after one, it confirms and moves to the next question and round clock', (t) async {
      _phone(t);
      final (svc, _) = await open(t, s: RoomService()..roundSeconds = 120);
      expect(find.byKey(const Key('round-timer')), findsOneWidget);
      await t.tap(find.text('Next question'));
      await t.pump();
      expect(svc.answers, isEmpty);
      expect(find.text('Answer the question first, or choose Skip.'), findsOneWidget);
      t.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).removeCurrentSnackBar();
      await t.pump();
      await t.enterText(find.byKey(const Key('answer-box')), 'my answer');
      await t.pump();
      await t.tap(find.byKey(const Key('send')));
      await _settle(t);
      await t.tap(find.text('Next question'));
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await _settle(t);
      expect(svc.answers.single, (0, false));
      expect(find.textContaining('Question 2 of 3'), findsWidgets);
      expect(find.textContaining('What does a database index cost?'), findsWidgets);
      expect(find.text('ROUND 5:00'), findsOneWidget);
    });

    testWidgets('the interviewer moving on by itself (advance) updates the question', (t) async {
      _phone(t);
      final svc = RoomService();
      svc.advanceOnNextTurn = {
        'hasNextQuestion': true,
        'nextQuestionIndex': 1,
        'nextQuestion': {'_id': 'q2', 'title': 'Indexes', 'description': 'What does a database index cost?', 'kind': 'conceptual'},
        'openingMessage': 'Question 2 of 3: What does a database index cost?',
      };
      await open(t, s: svc);
      await t.enterText(find.byKey(const Key('answer-box')), 'threads share the heap');
      await t.pump();
      await t.tap(find.byKey(const Key('send')));
      await _settle(t);
      await t.pump(const Duration(milliseconds: 800));
      await _settle(t);
      expect(find.textContaining('Question 2 of 3'), findsWidgets);
    });

    testWidgets('coding hold: the waiting question is hidden, the answer box is replaced, skip continues', (t) async {
      _phone(t);
      final (svc, _) = await open(t, s: RoomService()..status = 'paused'..holdFor = 'coding');
      expect(find.byKey(const Key('hold-card')), findsOneWidget);
      expect(find.byKey(const Key('answer-box')), findsNothing);
      expect(find.text('CODING ROUND NEXT'), findsOneWidget);
      expect(find.textContaining('next round starts after the coding round'), findsOneWidget);
      await t.tap(find.text('Skip coding round'));
      await t.pumpAndSettle();
      await t.tap(find.text('Skip'));
      await _settle(t);
      expect(svc.codingSkipped, isTrue);
      expect(find.byKey(const Key('hold-card')), findsNothing);
      expect(find.byKey(const Key('answer-box')), findsOneWidget);
    });

    testWidgets('system-design board: add, connect, save; the text form is shown; a diagram counts as an answer', (t) async {
      _phone(t);
      final (svc, _) = await open(t, s: RoomService()..kind = 'system-design');
      await t.tap(find.text('Draw the architecture'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('component-name')), 'API');
      await t.tap(find.byKey(const Key('add-component')));
      await t.pump();
      await t.enterText(find.byKey(const Key('component-name')), 'Postgres');
      await t.tap(find.byKey(const Key('component-type')));
      await t.pumpAndSettle();
      await t.tap(find.text('Database').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('add-component')));
      await t.pump();
      await t.tap(find.byKey(const Key('edge-from')));
      await t.pumpAndSettle();
      await t.tap(find.text('API').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('edge-to')));
      await t.pumpAndSettle();
      await t.tap(find.text('Postgres').last);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('connect')));
      await t.pump();
      expect(t.widget<Text>(find.byKey(const Key('diagram-status'))).data, 'Unsaved changes');
      expect(t.widget<Text>(find.byKey(const Key('diagram-text'))).data,
          'What the interviewer reads: Diagram components: API (service), Postgres (database). Diagram connections: API -> Postgres.');
      await t.ensureVisible(find.byKey(const Key('save-diagram')));
      await t.tap(find.byKey(const Key('save-diagram')));
      await _settle(t);
      expect((svc.savedScene!['nodes'] as List).length, 2);
      expect(t.widget<Text>(find.byKey(const Key('diagram-status'))).data, 'Saved');
      // No chat message, but the diagram is an answer: Next goes to the confirmation.
      await t.ensureVisible(find.text('Next question'));
      await t.tap(find.text('Next question'));
      await t.pumpAndSettle();
      expect(find.text('Next question?'), findsOneWidget);
    });
  });

  group('setup wizard', () {
    testWidgets('three kinds; DSA sends dsa_interview on the dsa track', (t) async {
      _phone(t);
      final svc = RoomService();
      await t.pumpWidget(_app(svc, const InterviewSetupScreen(initialMode: InterviewModes.dsa)));
      await _settle(t);
      expect(find.text('General / HR interview'), findsOneWidget);
      expect(find.text('Technical interview'), findsOneWidget);
      expect(find.text('DSA interview'), findsOneWidget);
      await t.ensureVisible(find.byKey(const Key('start-interview')));
      await t.tap(find.byKey(const Key('start-interview')));
      await _settle(t);
      expect(svc.createdWith!['interviewMode'], 'dsa_interview');
      expect(svc.createdWith!['track'], 'dsa');
    });

    testWidgets('technical without a preset sends technical_interview; with a preset, rounds, timer and a mid-interview coding round', (t) async {
      _phone(t);
      final svc = RoomService();
      await t.pumpWidget(_app(svc, const InterviewSetupScreen(initialMode: InterviewModes.technical)));
      await _settle(t);
      await t.ensureVisible(find.byKey(const Key('start-interview')));
      await t.tap(find.byKey(const Key('start-interview')));
      await _settle(t);
      expect(svc.createdWith!['interviewMode'], 'technical_interview');
      expect(svc.createdWith!['track'], 'general');

      await t.tap(find.byKey(const Key('plan-preset-campus')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('strict-rounds')));
      await t.tap(find.byKey(const Key('strict-rounds')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('coding-round')));
      await t.tap(find.byKey(const Key('coding-round')));
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('coding-when')));
      await t.tap(find.byKey(const Key('coding-when')));
      await t.pumpAndSettle();
      await t.tap(find.text('After the core technical knowledge round').last);
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const Key('start-interview')));
      await t.tap(find.byKey(const Key('start-interview')));
      await _settle(t);
      final b = svc.createdWith!;
      expect(b['preset'], 'campus');
      expect(b.containsKey('interviewMode'), isFalse, reason: 'with a preset the server derives job vs technical');
      expect(b['enforceRoundTimers'], isTrue);
      expect((b['codingRound'] as Map)['afterRoundKey'], 'technical');
    });
  });

  group('results report', () {
    testWidgets('renders the evidence report and offers to continue the interview after a mid-interview coding round', (t) async {
      _phone(t);
      final svc = RoomService()
        ..resultsBody = {
          'interviewMode': 'dsa_interview',
          'track': 'dsa',
          'summary': 'Solid work.',
          'loop': {'step': 'coding', 'generalOpen': true, 'generalSessionId': 'g1', 'codingPlanned': true},
          'report': {
            'provisional': false,
            'overallScore': 77,
            'competencies': [
              {'name': 'Technical correctness', 'status': 'scored', 'score': 100, 'maxScore': 100, 'evidence': []},
              {
                'name': 'Problem solving',
                'status': 'scored',
                'score': 20,
                'maxScore': 100,
                'evidence': [
                  {'type': 'message', 'excerpt': 'I would read both numbers'}
                ]
              },
              {'name': 'Communication clarity', 'status': 'insufficient_evidence'},
            ],
          },
          'questions': [
            {'reached': true, 'title': 'Max of Two', 'score': 100, 'testsPassed': 3, 'testsTotal': 3, 'feedback': 'All tests passed'},
            {'reached': false, 'title': 'Not reached', 'score': 0},
          ],
        };
      await t.pumpWidget(_app(svc, const InterviewResultsScreen(sessionId: 'c1')));
      await _settle(t);
      expect(t.widget<Text>(find.byKey(const Key('overall-score'))).data, '77');
      expect(find.text('Overall score'), findsOneWidget);
      expect(find.text('Problem solving'), findsOneWidget);
      expect(find.text('20/100'), findsOneWidget);
      expect(find.text('Insufficient evidence'), findsOneWidget);
      expect(find.textContaining('Your answer: "I would read both numbers"'), findsOneWidget);
      expect(find.byKey(const Key('continue-interview')), findsOneWidget);
      await t.scrollUntilVisible(find.text('Not reached').first, 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Not reached'), findsWidgets);
    });
  });

  group('small phones (360 dp wide): no overflow', () {
    void small(WidgetTester t) {
      t.view.physicalSize = const Size(720, 1600);
      t.view.devicePixelRatio = 2.0;
      addTearDown(t.view.reset);
    }

    testWidgets('room, round timer and coding hold card', (t) async {
      small(t);
      for (final svc in [RoomService()..roundSeconds = 300, RoomService()..status = 'paused'..holdFor = 'coding'..roundSeconds = 59]) {
        final initial = await svc.session('s1');
        await t.pumpWidget(_app(svc, ConversationalRoom(key: UniqueKey(), sessionId: 's1', initial: initial, voice: FakeVoice())));
        await _settle(t);
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('setup wizard with a preset, all options open', (t) async {
      small(t);
      final svc = RoomService();
      await t.pumpWidget(_app(svc, const InterviewSetupScreen(initialMode: InterviewModes.technical)));
      await _settle(t);
      await t.scrollUntilVisible(find.byKey(const Key('plan-preset-campus')), 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.byKey(const Key('plan-preset-campus')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('plan-preset-campus')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const Key('coding-round')), 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.byKey(const Key('coding-round')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('coding-round')));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.byKey(const Key('coding-when')), 200, scrollable: find.byType(Scrollable).first);
      await t.ensureVisible(find.byKey(const Key('coding-when')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('coding-when')));
      await t.pumpAndSettle();
      await t.tap(find.text('After the core technical knowledge round').last);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  });
}
