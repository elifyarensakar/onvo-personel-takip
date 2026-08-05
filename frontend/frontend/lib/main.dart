import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'state/app_data.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppData(),
      child: const OnvoApp(),
    ),
  );
}

class OnvoApp extends StatelessWidget {
  const OnvoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Onvo',
      debugShowCheckedModeBanner: false,
      theme: buildOnvoTheme(),
      home: const LoginScreen(),
    );
  }
}
