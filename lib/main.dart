import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'core/token_store.dart';
import 'screens/splash_screen.dart';
import 'services/feature_services.dart';
import 'services/services.dart';
import 'state/app_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final tokens = TokenStore();
  final api = ApiClient(tokens);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<TokenStore>.value(value: tokens),
        // Core session
        ChangeNotifierProvider(create: (_) => AuthController(api, tokens)),
        ChangeNotifierProvider(create: (_) => ThemeController(tokens)),
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
    final themeMode = context.watch<ThemeController>().mode;
    return MaterialApp(
      title: 'DSA Mentor',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: buildEmberTheme(dark: false),
      darkTheme: buildEmberTheme(dark: true),
      home: const SplashScreen(),
    );
  }
}
