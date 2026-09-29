import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/token_store.dart';
import 'screens/splash_screen.dart';
import 'services/feature_services.dart';
import 'services/services.dart';
import 'services/signup_verification.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PhoneVerifier.initialize();
  final tokens = TokenStore();
  final api = ApiClient(tokens);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<TokenStore>.value(value: tokens),
        // Core session
        ChangeNotifierProvider(create: (_) => AuthController(api, tokens)),
        ChangeNotifierProvider(create: (_) => ThemeController(tokens, api)),
        // Feature services
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
}

class DsaMentorApp extends StatelessWidget {
  const DsaMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themes = context.watch<ThemeController>();
    return MaterialApp(
      title: 'DSA Mentor',
      debugShowCheckedModeBanner: false,
      themeMode: themes.mode,
      theme: themes.lightTheme,
      darkTheme: themes.darkTheme,
      home: const SplashScreen(),
    );
  }
}
