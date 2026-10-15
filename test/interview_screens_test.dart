// Widget tests for the interview screens, driven by a fake InterviewService.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dsa_mentor/core/api_client.dart';
import 'package:dsa_mentor/core/token_store.dart';
import 'package:dsa_mentor/models/content.dart';
import 'package:dsa_mentor/screens/interview_screens.dart';
import 'package:dsa_mentor/services/feature_services.dart';

class FakeInterviewService extends InterviewService {
  FakeInterviewService() : super(ApiClient(TokenStore()));

  // results: first call pending, later calls done (as the real server behaves)
  int resultsCalls = 0;
  Map<String, dynamic> pendingResults = {
    'overallScore': 90,
    'rubricStatus': 'pending',
    'summary': 'Great job! You showed strong technical skills with room for minor improvements.',
  };
  Map<String, dynamic> doneResults = {
    'overallScore': 88,
    'rubricStatus': 'done',
    'summary': 'Great job! You showed strong technical skills with room for minor improvements.',
    'rubric': {
      'problemSolving': {'score': 50, 'evidence': 'I would use a hash map', 'rationale': 'ok', 'flagged': false},
      'communication': {'score': null, 'evidence': '', 'rationale': '', 'flagged': true},
    },
  };
  @override
  Future<Map<String, dynamic>> results(String sessionId) async {
    resultsCalls++;
    return resultsCalls == 1 ? pendingResults : doneResults;
  }

  // session
  String status = 'paused';
  int paused = 0, resumed = 0, sent = 0, hints = 0;
  List<Map<String, dynamic>> stored = [
    {'role': 'user', 'content': 'I will use a hash map', 'kind': 'chat'},
    {'role': 'ai', 'content': 'Why a hash map instead of sorting?', 'kind': 'chat'},
  ];
  @override
  Future<InterviewSession> session(String sessionId) async => InterviewSession(
        id: sessionId,
        status: status,
        timeRemaining: 1500,
        duration: 30,
        totalQuestions: 1,
        questions: [InterviewQuestion(title: 'Two Sum', description: 'Find two numbers.')],
        messages: stored,
      );
  @override
  Future<InterviewClock> pause(String sessionId) async {
    paused++;
    status = 'paused';
    return InterviewClock(status: 'paused', timeRemaining: 1490);
  }

  @override
  Future<InterviewClock> resume(String sessionId) async {
    resumed++;
    status = 'in-progress';
    return InterviewClock(status: 'in-progress', timeRemaining: 1490);
  }

  final sentIds = <String?>[];
  bool failNext = false;
  @override
  Future<String> sendMessage(String sessionId, String message, {String? code, String? clientMessageId}) async {
    sent++;
    sentIds.add(clientMessageId);
    if (failNext) {
      failNext = false;
      throw ApiException('The server took too long to respond.');
    }
    return 'What about duplicates?';
  }

  @override
  Future<String> hint(String sessionId) async {
    hints++;
    return 'Think about edge cases.';
  }
}

Widget _app(FakeInterviewService svc, Widget home) => MaterialApp(
      home: Provider<InterviewService>.value(value: svc, child: home),
    );

void main() {
  group('Results screen', () {
    testWidgets('shows provisional notice, then the rubric with evidence, without a manual refresh', (tester) async {
      final svc = FakeInterviewService();
      await tester.pumpWidget(_app(svc, const InterviewResultsScreen(sessionId: 's1')));
      await tester.pump(); // first load -> pending
      await tester.pump();
      expect(find.textContaining('still writing detailed feedback'), findsOneWidget);
      expect(find.text('Interviewer rubric'), findsNothing);

      await tester.pump(const Duration(seconds: 7)); // poll fires, second load -> done
      await tester.pump();
      expect(find.textContaining('still writing detailed feedback'), findsNothing);
      expect(find.text('Interviewer rubric'), findsOneWidget);
      expect(find.text('Problem solving'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('"I would use a hash map"'), findsOneWidget);
      expect(find.text('Not enough evidence'), findsOneWidget); // flagged dimension gets no score
      expect(svc.resultsCalls, 2);

      // no further polling once final
      await tester.pump(const Duration(seconds: 20));
      expect(svc.resultsCalls, 2);
    });

    testWidgets('a failed load shows the error instead of spinning forever', (tester) async {
      final svc = _FailingResults();
      await tester.pumpWidget(_app(svc, const InterviewResultsScreen(sessionId: 's1')));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Results not found'), findsOneWidget);
    });
  });

  group('Session screen', () {
    testWidgets('restores the stored conversation and the paused state; Resume restarts it', (tester) async {
      final svc = FakeInterviewService();
      await tester.pumpWidget(_app(svc, const InterviewSessionScreen(sessionId: 's1')));
      await tester.pump();
      await tester.pump();
      // stored conversation is back after a (re)open
      expect(find.text('Why a hash map instead of sorting?'), findsOneWidget);
      expect(find.text('I will use a hash map'), findsOneWidget);
      // paused: banner + Resume, chat input disabled
      expect(find.textContaining('Paused'), findsOneWidget);
      expect(find.text('Resume'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      expect(field.enabled, isFalse);

      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.pump();
      expect(svc.resumed, 1);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.textContaining('Paused —'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField).first).enabled, isTrue);
    });

    testWidgets('a failed send keeps the text and retries with the SAME message id', (tester) async {
      final svc = FakeInterviewService()
        ..status = 'in-progress'
        ..stored = []
        ..failNext = true;
      await tester.pumpWidget(_app(svc, const InterviewSessionScreen(sessionId: 's1')));
      await tester.pump();
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'my approach');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();
      // failed: the bubble is taken back and the text is restored for a retry
      expect(find.text('The server took too long to respond.'), findsOneWidget); // snackbar
      expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'my approach');

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();
      expect(svc.sent, 2);
      expect(svc.sentIds[0], isNotNull);
      expect(svc.sentIds[1], svc.sentIds[0]); // same logical message, same id => server answers once
      expect(find.text('What about duplicates?'), findsOneWidget);
      expect(find.text('my approach'), findsOneWidget); // exactly one candidate bubble
    });

    testWidgets('different text after a successful send gets a new id', (tester) async {
      final svc = FakeInterviewService()
        ..status = 'in-progress'
        ..stored = [];
      await tester.pumpWidget(_app(svc, const InterviewSessionScreen(sessionId: 's1')));
      await tester.pump();
      await tester.pump();
      for (final t in ['first', 'second']) {
        await tester.enterText(find.byType(TextField).first, t);
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();
        await tester.pump();
      }
      expect(svc.sentIds.toSet().length, 2);
    });
  });
}

class _FailingResults extends FakeInterviewService {
  @override
  Future<Map<String, dynamic>> results(String sessionId) async => throw ApiException('Results not found.');
}
