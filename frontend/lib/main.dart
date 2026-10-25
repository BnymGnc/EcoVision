import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login_screen.dart';
import 'screens/main_tab_navigator.dart';
import 'screens/onboarding_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const EcoVisionApp());
}

class EcoVisionApp extends StatefulWidget {
  const EcoVisionApp({this.apiService, this.themeController, super.key});

  final ApiService? apiService;
  final ThemeController? themeController;

  @override
  State<EcoVisionApp> createState() => _EcoVisionAppState();
}

class _EcoVisionAppState extends State<EcoVisionApp> {
  late final ThemeController _themeController;
  late final ApiService _apiService;
  late Future<_StartupRoute> _startup;

  @override
  void initState() {
    super.initState();
    _themeController = widget.themeController ?? ThemeController();
    _apiService = widget.apiService ?? ApiService();
    _startup = _initialize();
  }

  Future<_StartupRoute> _initialize() async {
    await _themeController.load();
    await _apiService.loadStoredSession();
    final user = _apiService.currentUser;
    if (user == null) return const _StartupRoute.auth();
    await _themeController.bindToUser(
      userId: user.id,
      remotePreference: user.themePreference,
      remoteSaver: (preference) async {
        await _apiService.updateThemePreference(preference);
      },
    );
    final seen = await OnboardingScreen.hasSeenForUser(user.id);
    return _StartupRoute.authenticated(user.id, seen);
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
            home: FutureBuilder<_StartupRoute>(
              future: _startup,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SplashScreen();
                }
                if (snapshot.hasError) {
                  return Scaffold(
                    body: SafeArea(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                size: 88,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Bağlantı kurulamadı',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Oturumun korundu. Bağlantını kontrol edip tekrar deneyebilirsin.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () => setState(() {
                                  _startup = _initialize();
                                }),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Yeniden Dene'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await _apiService.logout();
                                  if (mounted) {
                                    setState(() {
                                      _startup = Future.value(
                                        const _StartupRoute.auth(),
                                      );
                                    });
                                  }
                                },
                                child: const Text('Başka hesapla giriş yap'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final route = snapshot.data ?? const _StartupRoute.auth();
                if (!route.authenticated) {
                  return LoginScreen(apiService: _apiService);
                }
                return route.hasSeenOnboarding
                    ? MainTabNavigator(apiService: _apiService)
                    : OnboardingScreen(
                        apiService: _apiService,
                        userId: route.userId!,
                      );
              },
            ),
          ),
        );
      },
    );
  }
}

class _StartupRoute {
  const _StartupRoute.auth()
    : authenticated = false,
      userId = null,
      hasSeenOnboarding = false;

  const _StartupRoute.authenticated(this.userId, this.hasSeenOnboarding)
    : authenticated = true;

  final bool authenticated;
  final int? userId;
  final bool hasSeenOnboarding;
}
