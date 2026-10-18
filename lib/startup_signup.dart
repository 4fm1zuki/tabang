import 'package:flutter/material.dart';
import 'signup_page.dart'; // Make sure this matches your file path

void main() {
  runApp(const TabangApp());
}

class TabangApp extends StatelessWidget {
  const TabangApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TABANG - Register',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9E2A2B),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9E2A2B),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      // Loads the SignUpPage directly by itself
      home: const SignUpPage(),
    );
  }
}