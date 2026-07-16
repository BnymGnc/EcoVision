import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'services/api_service.dart';

void main() {
  runApp(const EcoVisionApp());
}

class EcoVisionApp extends StatelessWidget {
  const EcoVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2E7D32),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'EcoVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme.copyWith(
          primary: const Color(0xFF2E7D32),
          secondary: const Color(0xFF7CB342),
          surface: const Color(0xFFFAFCF7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6FAF2),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: LoginScreen(apiService: ApiService()),
    );
  }
}
