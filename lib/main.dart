import 'package:flutter/material.dart';

import 'screens/web_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DsaMentorApp());
}

class DsaMentorApp extends StatelessWidget {
  const DsaMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'DSA Mentor',
      debugShowCheckedModeBanner: false,
      home: WebShell(),
    );
  }
}
