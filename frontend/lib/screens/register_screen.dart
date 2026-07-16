import 'package:flutter/material.dart';

import '../services/api_service.dart';
import 'main_tab_navigator.dart';

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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => MainTabNavigator(apiService: widget.apiService),
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
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Start your green streak',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your account is stored securely through the EcoVision backend.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 26),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _surnameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Surname',
                      prefixIcon: Icon(Icons.badge_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Surname is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Email is required'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    onChanged: (value) => setState(() => _password = value),
                    decoration: const InputDecoration(
                      labelText: 'Password',
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
                      labelText: 'Age',
                      prefixIcon: Icon(Icons.cake_outlined),
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final age = int.tryParse(value ?? '');
                      return age == null || age < 1 ? 'Enter your age' : null;
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
                    label: const Text('Register'),
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
      return 'Use at least 8 characters';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least one uppercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Add at least one number';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=;]').hasMatch(password)) {
      return 'Add at least one special character';
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
      0 || 1 => 'Weak',
      2 || 3 => 'Getting stronger',
      _ => 'Strong',
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
          '$label password: 8+ chars, uppercase, number, special character',
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}
