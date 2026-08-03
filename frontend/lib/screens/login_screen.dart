import 'package:flutter/material.dart';

import '../core/auth_validators.dart';
import '../services/api_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/auth_loading_overlay.dart';
import 'main_tab_navigator.dart';
import 'onboarding_screen.dart';
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
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String _loadingMessage = 'Güvenli giriş yapılıyor...';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    widget.apiService.setRememberMe(_rememberMe);
    _beginLoading();
    try {
      await widget.apiService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) await _openApp();
    } catch (error) {
      if (mounted) {
        _endLoading();
        _showError(error);
      }
    }
  }

  Future<void> _openApp() async {
    final user = widget.apiService.currentUser!;
    await ThemeScope.of(context).bindToUser(
      userId: user.id,
      remotePreference: user.themePreference,
      remoteSaver: (preference) async {
        await widget.apiService.updateThemePreference(preference);
      },
    );
    final hasSeenOnboarding = await OnboardingScreen.hasSeenForUser(user.id);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => hasSeenOnboarding
            ? MainTabNavigator(apiService: widget.apiService)
            : OnboardingScreen(apiService: widget.apiService, userId: user.id),
      ),
      (_) => false,
    );
  }

  void _beginLoading() {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Güvenli giriş yapılıyor...';
    });
  }

  void _endLoading() {
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(text: _emailController.text);
    final submitted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parolamı Unuttum'),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'E-posta',
            prefixIcon: Icon(Icons.mark_email_read_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bağlantı Gönder'),
          ),
        ],
      ),
    );
    if (submitted != true || !mounted) {
      emailController.dispose();
      return;
    }
    final validation = AuthValidators.email(emailController.text);
    if (validation != null) {
      _showError(validation);
      emailController.dispose();
      return;
    }
    setState(() => _isLoading = true);
    try {
      await widget.apiService.requestPasswordReset(emailController.text);
      if (mounted) {
        setState(() => _isLoading = false);
        _showMessage('Hesap mevcutsa parola sıfırlama talimatları gönderildi.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(error);
      }
    } finally {
      emailController.dispose();
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: AuthLoadingOverlay(
        visible: _isLoading,
        message: _loadingMessage,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.20),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.eco_rounded,
                            size: 42,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "EcoVision'a Hoş Geldin",
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Atıklarını dönüştür, etkini ölç ve şehrinle birlikte harekete geç.',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                      const SizedBox(height: 30),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        validator: AuthValidators.email,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _login(),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Parola zorunludur'
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Parola',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Parolayı göster'
                                : 'Parolayı gizle',
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) =>
                                setState(() => _rememberMe = value ?? false),
                          ),
                          const Expanded(child: Text('Beni hatırla')),
                          TextButton(
                            onPressed: _isLoading ? null : _forgotPassword,
                            child: const Text('Parolamı Unuttum'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _login,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Giriş Yap'),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => RegisterScreen(
                                    apiService: widget.apiService,
                                  ),
                                ),
                              ),
                        child: const Text('Yeni hesap oluştur'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
