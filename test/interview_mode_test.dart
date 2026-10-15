// Mode contract, diagram text parity with the server, and the new session/catalog fields.
import 'package:flutter_test/flutter_test.dart';

import 'package:dsa_mentor/core/api_client.dart';
import 'package:dsa_mentor/models/content.dart';
import 'package:dsa_mentor/models/interview_mode.dart';

void main() {
  group('roomKind', () {
    test('the stored mode decides; a problem object or title never does', () {
      expect(roomKind(interviewMode: 'dsa_interview', track: 'general'), 'dsa');
      expect(roomKind(interviewMode: 'technical_interview', track: 'dsa'), 'conversational');
      expect(roomKind(interviewMode: 'job_interview'), 'conversational');
    });
    test('older servers: track decides; unknown values never open the editor', () {
      expect(roomKind(track: 'general'), 'conversational');
      expect(roomKind(track: 'dsa'), 'dsa');
      expect(roomKind(), 'dsa');
      expect(roomKind(track: 'something-new'), 'conversational');
      expect(roomKind(interviewMode: 'garbage', track: 'dsa'), 'conversational');
    });
    test('labels and tracks', () {
      expect(modeLabel(interviewMode: 'technical_interview'), 'Technical');
      expect(modeLabel(track: 'dsa'), 'DSA');
      expect(InterviewModes.trackFor(InterviewModes.dsa), 'dsa');
      expect(InterviewModes.trackFor(InterviewModes.job), 'general');
    });
  });

  group('DiagramScene', () {
    test('text form matches the server (backend diagram.sceneToText) for every kind', () {
      final s = DiagramScene();
      expect(s.addNode('Load balancer', 'load-balancer'), isTrue);
      expect(s.addNode('Redis', 'cache'), isTrue);
      expect(s.addEdge('n1', 'n2', 'reads'), isTrue);
      // Same string the backend unit test expects.
      expect(s.toText(), 'Diagram components: Load balancer (load balancer), Redis (cache). Diagram connections: Load balancer -> Redis (reads).');
      final all = DiagramScene();
      for (final k in DiagramScene.kinds.keys) {
        all.addNode('P $k', k);
      }
      expect(all.toText(), contains('P storage (object storage)'));
      expect(all.toText(), contains('P other (component)'));
      expect(all.toText(), contains('P external (external system)'));
    });
    test('rules: no empty labels, self loops, duplicates or unknown ends; bounded', () {
      final s = DiagramScene();
      expect(s.addNode('   ', 'service'), isFalse);
      s.addNode('A', 'service');
      s.addNode('B', 'nope');
      expect(s.nodes[1].kind, 'other');
      expect(s.addEdge('n1', 'n1', ''), isFalse);
      expect(s.addEdge('n1', 'zz', ''), isFalse);
      expect(s.addEdge('n1', 'n2', ''), isTrue);
      expect(s.addEdge('n1', 'n2', 'again'), isFalse);
      s.removeNode('n1');
      expect(s.edges, isEmpty);
      final big = DiagramScene();
      for (var i = 0; i < 40; i++) {
        big.addNode('x' * 60, 'service');
      }
      expect(big.nodes.length, DiagramScene.maxNodes);
      expect(big.nodes.first.label.length, DiagramScene.maxLabel);
      expect(DiagramScene.fromMap(big.toMap()).nodes.length, DiagramScene.maxNodes);
    });
  });

  group('InterviewSession.fromMap (current server)', () {
    test('reads mode, rounds, round timer, coding hold, current question and diagram', () {
      final s = InterviewSession.fromMap({
        'success': true,
        'session': {
          '_id': 's1',
          'status': 'paused',
          'interviewMode': 'technical_interview',
          'track': 'general',
          'mode': 'simulation',
          'currentQuestionIndex': 3,
          'totalQuestions': 6,
          'rounds': [
            {'key': 'technical', 'label': 'Core technical knowledge', 'minutes': 15, 'start': 0, 'count': 3},
            {'key': 'behavioral', 'label': 'Behavioral', 'minutes': 7, 'start': 3, 'count': 1},
          ],
          'roundTimer': {'enforced': true, 'secondsRemaining': 412, 'finished': false},
          'hold': {
            'for': 'coding',
            'coding': {'questionCount': 2, 'duration': 30}
          },
          'currentQuestion': {'_id': 'q', 'title': '', 'description': '', 'kind': 'behavioral', 'examples': []},
          'currentDiagram': {
            'nodes': [
              {'id': 'n1', 'label': 'API', 'kind': 'service', 'x': 1, 'y': 2}
            ],
            'edges': []
          },
        }
      });
      expect(s.interviewMode, 'technical_interview');
      expect(s.rounds.length, 2);
      expect(s.roundIndex, 1);
      expect(s.roundTimerEnforced, isTrue);
      expect(s.roundSecondsRemaining, 412);
      expect(s.holdFor, 'coding');
      expect(s.holdCodingQuestions, 2);
      expect(s.holdCodingMinutes, 30);
      expect(s.openQuestion!.kind, 'behavioral');
      expect(DiagramScene.fromMap(s.currentDiagram).nodes.single.label, 'API');
    });
    test('DSA question fields: examples and starter code', () {
      final q = InterviewQuestion.fromMap({
        'title': 'Two Sum',
        'difficulty': 'Easy',
        'topics': ['Arrays'],
        'examples': [
          {'input': '1 2', 'output': '3'}
        ],
        'starterCode': {'python': 'print()', 'javascript': 'console.log()'},
      });
      expect(q.examples.single['output'], '3');
      expect(q.starterCode['python'], 'print()');
      expect(q.topics, ['Arrays']);
    });
  });

  test('catalog: HR is a job interview, others technical', () {
    final c = InterviewCatalog.fromMap({
      'presets': [
        {
          'id': 'campus',
          'label': 'Campus',
          'track': 'swe',
          'rounds': [
            {'key': 'technical', 'label': 'Core', 'count': 3, 'minutes': 15}
          ]
        }
      ],
      'tracks': [
        {'id': 'hr', 'label': 'HR and behavioral', 'group': 'Behavioral'},
        {'id': 'backend', 'label': 'Backend', 'group': 'Software'}
      ],
      'experienceLevels': [
        {'id': 'fresher', 'label': 'Fresher', 'difficulty': 'easy'}
      ],
    });
    expect(c.presets.single.rounds.single.key, 'technical');
    expect(c.presets.single.interviewMode, InterviewModes.technical);
    expect(c.tracks.first.interviewMode, InterviewModes.job);
    expect(c.tracks.last.interviewMode, InterviewModes.technical);
  });

  test('ApiException carries the server code', () {
    final e = ApiException('Time is up for this round.', statusCode: 409, code: 'ROUND_TIME_UP');
    expect(e.code, 'ROUND_TIME_UP');
    expect(e.toString(), 'Time is up for this round.');
  });

  test('resume profile: parse, edit, send only kept items', () {
    final r = ResumeProfile.fromMap({
      'profile': {
        'skills': ['React', 'Node'],
        'projects': [
          {'title': 'Chat app', 'details': 'Socket.IO'}
        ],
        'experience': [],
        'achievements': []
      },
      'hints': ['Two-column layout detected.']
    });
    expect(r.itemCount, 3);
    r.skills.remove('Node');
    expect(r.toMap()['skills'], ['React']);
    expect(r.hints.single, contains('Two-column'));
  });
}
