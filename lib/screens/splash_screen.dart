import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';
import '../widgets/widgets.dart';
import 'landing_screen.dart';
import 'main_shell.dart';

/// Restores the session (if any), then routes to the shell or the login form.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final auth = context.read<AuthController>();
    await auth.bootstrap();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            auth.user != null ? const MainShell() : const LandingScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppPalette.of(context).gradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppPalette.of(context).onGradient.withAlpha(40),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const BrandMark(size: 72),
              ),
              const SizedBox(height: 22),
              Text(
                'DSA Mentor',
                style: theme.textTheme.headlineMedium?.copyWith(color: AppPalette.of(context).onGradient),
              ),
              const SizedBox(height: 6),
              Text(
                'Practice. Review. Improve.',
                style: theme.textTheme.bodyMedium?.copyWith(color: AppPalette.of(context).onGradient.withAlpha(210)),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: AppPalette.of(context).onGradient),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
