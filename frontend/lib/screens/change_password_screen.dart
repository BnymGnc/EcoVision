import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _saving = false;
  bool _showCurrent = false;
  bool _showNew = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.apiService.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parola başarıyla değiştirildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final password = _newController.text;
    final rules = <(String, bool)>[
      ('En az 8 karakter', password.length >= 8),
      ('Bir büyük harf', RegExp(r'[A-Z]').hasMatch(password)),
      ('Bir rakam', RegExp(r'\d').hasMatch(password)),
      ('Bir özel karakter', RegExp(r'[^A-Za-z0-9]').hasMatch(password)),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Parolayı Değiştir')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Hesabını koru',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            'Başka yerde kullanmadığın güçlü bir parola seç.',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _currentController,
                  obscureText: !_showCurrent,
                  decoration: InputDecoration(
                    labelText: 'Mevcut Parola',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: _showCurrent
                          ? 'Parolayı gizle'
                          : 'Parolayı göster',
                      onPressed: () =>
                          setState(() => _showCurrent = !_showCurrent),
                      icon: Icon(
                        _showCurrent ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Mevcut parola zorunludur'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _newController,
                  obscureText: !_showNew,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Yeni Parola',
                    prefixIcon: const Icon(Icons.password_outlined),
                    suffixIcon: IconButton(
                      tooltip: _showNew ? 'Parolayı gizle' : 'Parolayı göster',
                      onPressed: () => setState(() => _showNew = !_showNew),
                      icon: Icon(
                        _showNew ? Icons.visibility_off : Icons.visibility,
                      ),
                    ),
                  ),
                  validator: (value) => _strongPassword(value ?? '')
                      ? null
                      : 'Parola tüm koşulları karşılamıyor',
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        for (final rule in rules)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                Icon(
                                  rule.$2
                                      ? Icons.check_circle
                                      : Icons.circle_outlined,
                                  color: rule.$2
                                      ? colors.primary
                                      : colors.outline,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(rule.$1),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Yeni Parolayı Doğrula',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                  validator: (value) => value != _newController.text
                      ? 'Parolalar eşleşmiyor'
                      : null,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_reset_outlined),
                  label: const Text('Parolayı Güncelle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _strongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }
}
