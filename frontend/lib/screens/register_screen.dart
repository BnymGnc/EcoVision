import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'onboarding_screen.dart';
import '../theme/theme_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ageController = TextEditingController();
  String _password = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.apiService.register(
        name: _nameController.text,
        surname: _surnameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        age: int.tryParse(_ageController.text),
      );
      if (!mounted) {
        return;
      }
      await ThemeScope.of(
        context,
      ).bindToUser(widget.apiService.currentUser!.id);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => OnboardingScreen(apiService: widget.apiService),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap Oluştur')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Yeşil yolculuğuna başla',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('Hesabın EcoVision sunucusunda güvenle korunur.'),
            const SizedBox(height: 26),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Ad',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Ad zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _surnameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Soyad',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Soyad zorunludur'
                        : null,
                  ),
                  const SizedBox(height: 14),
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
                    onChanged: (value) => setState(() => _password = value),
                    decoration: const InputDecoration(
                      labelText: 'Parola',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 10),
                  _PasswordStrengthIndicator(password: _password),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Yaş',
                      prefixIcon: Icon(Icons.cake_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final age = int.tryParse(value ?? '');
                      return age == null || age < 1
                          ? 'Geçerli bir yaş girin'
                          : null;
                    },
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isLoading ? null : _register,
                    icon: _isLoading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    label: const Text('Kayıt Ol'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8) {
      return 'En az 8 karakter kullanın';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'En az bir büyük harf ekleyin';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'En az bir rakam ekleyin';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=;]').hasMatch(password)) {
      return 'En az bir özel karakter ekleyin';
    }
    return null;
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  int get score {
    var value = 0;
    if (password.length >= 8) value++;
    if (RegExp(r'[A-Z]').hasMatch(password)) value++;
    if (RegExp(r'[0-9]').hasMatch(password)) value++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=;]').hasMatch(password)) value++;
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (score) {
      0 || 1 => Theme.of(context).colorScheme.error,
      2 || 3 => Colors.amber.shade700,
      _ => Theme.of(context).colorScheme.primary,
    };
    final label = switch (score) {
      0 || 1 => 'Zayıf',
      2 || 3 => 'Güçleniyor',
      _ => 'Güçlü',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: score / 4,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: color,
        ),
        const SizedBox(height: 6),
        Text(
          '$label parola: 8+ karakter, büyük harf, rakam ve özel karakter',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
