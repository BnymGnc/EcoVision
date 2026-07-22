import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'main_tab_navigator.dart';
import 'onboarding_screen.dart';
import '../theme/theme_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.apiService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        _openApp();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(error);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      await widget.apiService.loginWithGoogle();
      if (mounted) {
        _openApp();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(error);
      }
    }
  }

  Future<void> _restoreSession() async {
    await widget.apiService.loadStoredSession();
    if (mounted && widget.apiService.isAuthenticated) {
      _openApp();
    }
  }

  Future<void> _openApp() async {
    final user = widget.apiService.currentUser!;
    await ThemeScope.of(context).bindToUser(user.id);
    final hasSeenOnboarding = await OnboardingScreen.hasSeenForUser(user.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => hasSeenOnboarding
            ? MainTabNavigator(apiService: widget.apiService)
            : OnboardingScreen(apiService: widget.apiService),
      ),
    );
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  void _openRegister() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RegisterScreen(apiService: widget.apiService),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.eco_outlined,
                      size: 40,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    "EcoVision'a Hoş Geldin",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Atıkları tara, puan kazan ve yerel temizlik hareketlerine katıl.',
                  ),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-posta',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'E-posta zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Parola',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Parola zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _login,
                    icon: _isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Giriş Yap'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Google ile Devam Et'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _isLoading ? null : _openRegister,
                    child: const Text('Hesap Oluştur'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
