// Unit tests for the interview API plumbing (no network).
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_mentor/core/api_client.dart';
import 'package:dsa_mentor/core/token_store.dart';
import 'package:dsa_mentor/models/content.dart';
import 'package:dsa_mentor/services/feature_services.dart';

void main() {
  group('ApiClient.unwrapOrBody (interview endpoints put fields beside `success`)', () {
    final api = ApiClient(TokenStore());

    test('returns the whole body when there is no `data` key', () {
      final body = {'success': true, 'response': 'Why a hash map?', 'phase': 'approach'};
      expect(api.unwrapOrBody(body), same(body));
    });

    test('still prefers `data` when the endpoint has one', () {
      expect(api.unwrapOrBody({'success': true, 'data': {'a': 1}}), {'a': 1});
    });

    test('turns success:false into an ApiException carrying the server message', () {
      expect(
        () => api.unwrapOrBody({'success': false, 'message': 'This interview is not active.'}),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'This interview is not active.')),
      );
    });

    test('the old unwrap() returned null for these bodies (the bug this fixes)', () {
      expect(api.unwrap({'success': true, 'response': 'x'}), isNull);
    });
  });

  group('InterviewSession.fromMap', () {
    test('reads the nested `session` the server sends, incl. status and stored messages', () {
      final s = InterviewSession.fromMap({
        'success': true,
        'session': {
          '_id': 'abc',
          'status': 'paused',
          'timeRemaining': 1420,
          'duration': 30,
          'currentQuestionIndex': 1,
          'totalQuestions': 2,
          'messages': [
            {'role': 'user', 'content': 'I will use a hash map', 'kind': 'chat'},
            {'role': 'ai', 'content': 'Why a hash map?', 'kind': 'chat'},
            {'role': 'ai', 'content': 'Think about edge cases.', 'kind': 'hint'},
          ],
          'questions': [
            {'title': 'Add Two Numbers', 'description': 'd1'},
            {'title': 'Max of Two', 'description': 'd2'},
          ],
        },
      });
      expect(s.id, 'abc');
      expect(s.status, 'paused');
      expect(s.timeRemaining, 1420);
      expect(s.currentIndex, 1);
      expect(s.messages.length, 3);
      expect(s.messages.first['role'], 'user');
      expect(s.questions[1].title, 'Max of Two');
    });

    test('server sends only reached questions; the total comes from totalQuestions', () {
      final s = InterviewSession.fromMap({
        'session': {
          '_id': 's1',
          'currentQuestionIndex': 1,
          'totalQuestions': 3,
          'questions': [
            {'title': 'Q1', 'description': 'd1'},
            {'title': 'Q2', 'description': 'd2'},
          ],
        },
      });
      expect(s.questions.length, 2);
      expect(s.totalQuestions, 3);
      expect(s.questions[s.currentIndex].title, 'Q2');
    });

    test('older payloads without status/messages still parse', () {
      final s = InterviewSession.fromMap({'_id': 'x', 'questions': []});
      expect(s.status, 'in-progress');
      expect(s.messages, isEmpty);
    });
  });

  group('RunOutcome', () {
    test('keeps the question the server chose next (adaptive difficulty may swap it)', () {
      final o = RunOutcome.from({
        'success': true,
        'feedback': 'ok',
        'hasNextQuestion': true,
        'nextQuestionIndex': 1,
        'passedTests': 3,
        'totalTests': 3,
        'nextQuestion': {'title': 'Harder One', 'description': 'new text', 'difficulty': 'Hard'},
      });
      expect(o.hasNextQuestion, isTrue);
      expect(o.nextQuestionIndex, 1);
      expect(o.nextQuestion?['title'], 'Harder One');
      expect(o.passedTests, 3);
      expect(InterviewQuestion.fromMap(o.nextQuestion!).title, 'Harder One');
    });

    test('run/submit bodies: pass counts come from the summary beside the per-test list', () {
      // Shape sent by the real backend (verified against a running server).
      final o = RunOutcome.from({
        'success': false,
        'passedTests': 1,
        'totalTests': 3,
        'results': [
          {'index': 0, 'passed': true, 'isHidden': false},
          {'index': 1, 'passed': false, 'isHidden': true},
          {'index': 2, 'passed': false, 'isHidden': true},
        ],
      });
      expect(o.passedTests, 1);
      expect(o.totalTests, 3);
    });

    test('last question: no next question', () {
      final o = RunOutcome.from({'success': true, 'hasNextQuestion': false, 'passedTests': 1, 'totalTests': 1});
      expect(o.hasNextQuestion, isFalse);
      expect(o.nextQuestion, isNull);
    });
  });

  group('pause/resume clock and retry ids', () {
    test('InterviewClock parses status and seconds, tolerates junk', () {
      final c = InterviewClock.from({'success': true, 'status': 'paused', 'timeRemaining': 900});
      expect(c.status, 'paused');
      expect(c.timeRemaining, 900);
      expect(InterviewClock.from(null).status, 'in-progress');
    });

    test('client message ids are unique per logical message and never empty', () async {
      final a = newClientMessageId('same text');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final b = newClientMessageId('same text');
      expect(a, isNotEmpty);
      expect(a, isNot(b));
      expect(a.length, lessThanOrEqualTo(64)); // the server stores at most 64 chars
    });
  });
}
