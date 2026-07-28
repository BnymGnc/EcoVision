import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const EcoVisionApp());
}

class EcoVisionApp extends StatefulWidget {
  const EcoVisionApp({super.key});

  @override
  State<EcoVisionApp> createState() => _EcoVisionAppState();
}

class _EcoVisionAppState extends State<EcoVisionApp> {
  final ThemeController _themeController = ThemeController();
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _themeController.load();
  }

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return ThemeScope(
          controller: _themeController,
          child: MaterialApp(
            title: 'EcoVision',
            debugShowCheckedModeBanner: false,
            locale: const Locale('tr', 'TR'),
            supportedLocales: const [Locale('tr', 'TR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: _themeController.themeData,
            home: _LaunchGate(apiService: _apiService),
          ),
        );
      },
    );
  }
}

class _LaunchGate extends StatelessWidget {
  const _LaunchGate({required this.apiService});

  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: OnboardingScreen.hasSeenOnThisDevice(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data!
            ? LoginScreen(apiService: apiService)
            : OnboardingScreen(apiService: apiService);
      },
    );
  }
}
