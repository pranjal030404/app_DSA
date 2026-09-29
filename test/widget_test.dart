// Basic smoke test: the app boots to the splash screen without throwing.
//
// Bootstrapping (session restore) is fired from a post-frame callback and
// talks to the network, so this test deliberately stops at a single `pump()`
// rather than `pumpAndSettle()` — it only needs to prove the widget tree
// builds under the same provider setup as `main.dart`, not that a live
// backend is reachable.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:dsa_mentor/core/api_client.dart';
import 'package:dsa_mentor/core/token_store.dart';
import 'package:dsa_mentor/main.dart';
import 'package:dsa_mentor/services/feature_services.dart';
import 'package:dsa_mentor/services/services.dart';
import 'package:dsa_mentor/state/app_state.dart';

void main() {
  testWidgets('App boots to the splash screen', (WidgetTester tester) async {
    final tokens = TokenStore();
    final api = ApiClient(tokens);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          Provider<TokenStore>.value(value: tokens),
          ChangeNotifierProvider(create: (_) => AuthController(api, tokens)),
          ChangeNotifierProvider(create: (_) => ThemeController(tokens, api)),
          Provider<AuthService>(create: (_) => AuthService(api)),
          Provider<ProblemService>(create: (_) => ProblemService(api)),
          Provider<MentorService>(create: (_) => MentorService(api)),
          Provider<PlaygroundService>(create: (_) => PlaygroundService(api)),
          Provider<InterviewService>(create: (_) => InterviewService(api)),
          Provider<RoadmapService>(create: (_) => RoadmapService(api)),
          Provider<AchievementsService>(create: (_) => AchievementsService(api)),
          Provider<HelpService>(create: (_) => HelpService(api)),
          Provider<ResourcesService>(create: (_) => ResourcesService(api)),
          Provider<SupportService>(create: (_) => SupportService(api)),
          Provider<DashboardService>(create: (_) => DashboardService(api)),
          Provider<CollabService>(create: (_) => CollabService(api)),
        ],
        child: const DsaMentorApp(),
      ),
    );

    // First frame: the splash screen renders while session restore kicks off.
    await tester.pump();
    expect(find.text('DSA Mentor'), findsOneWidget);
  });
}
