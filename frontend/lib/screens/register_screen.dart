import 'package:flutter/material.dart';

import '../core/auth_validators.dart';
import '../core/turkey_locations.dart';
import '../services/api_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/auth_loading_overlay.dart';
import 'main_tab_navigator.dart';
import 'onboarding_screen.dart';

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
  final _confirmPasswordController = TextEditingController();

  DateTime? _dateOfBirth;
  String _province = 'Şanlıurfa';
  late String _district;
  String _password = '';
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _district = TurkishLocations.districtsFor(_province).first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final now = DateTime.now();
    final latestAllowed = DateTime(now.year - 13, now.month, now.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: latestAllowed,
      helpText: 'Doğum Tarihini Seç',
      cancelText: 'Vazgeç',
      confirmText: 'Seç',
    );
    if (selected != null) setState(() => _dateOfBirth = selected);
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      _showError('Doğum tarihi zorunludur');
      return;
    }
    if (!_termsAccepted || !_privacyAccepted) {
      _showError(
        'Kayıt için Kullanım Koşulları ve Gizlilik Politikası kabul edilmelidir',
      );
      return;
    }

    widget.apiService.setRememberMe(true);
    setState(() => _isLoading = true);
    try {
      await widget.apiService.register(
        name: _nameController.text,
        surname: _surnameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        dateOfBirth: _dateOfBirth,
        city: _province,
        district: _district,
        termsAccepted: _termsAccepted,
        privacyAccepted: _privacyAccepted,
      );
      if (!mounted) return;
      await ThemeScope.of(
        context,
      ).bindToUser(widget.apiService.currentUser!.id);
      final userId = widget.apiService.currentUser!.id;
      final hasSeenOnboarding = await OnboardingScreen.hasSeenForUser(userId);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => hasSeenOnboarding
              ? MainTabNavigator(apiService: widget.apiService)
              : OnboardingScreen(apiService: widget.apiService, userId: userId),
        ),
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(error.toString());
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showLegalDocument(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              Text(body, style: const TextStyle(height: 1.5)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Anladım'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap Oluştur')),
      body: AuthLoadingOverlay(
        visible: _isLoading,
        message: 'Hesabın güvenle oluşturuluyor...',
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                Text(
                  'Yeşil yolculuğuna başla',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '13 yaş ve üzeri kullanıcılar için güvenli EcoVision hesabı.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.givenName],
                        decoration: const InputDecoration(
                          labelText: 'Ad',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: _requiredName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _surnameController,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.familyName],
                        decoration: const InputDecoration(labelText: 'Soyad'),
                        validator: _requiredName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
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
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (value) => setState(() => _password = value),
                  validator: AuthValidators.password,
                  decoration: InputDecoration(
                    labelText: 'Parola',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Parolayı göster'
                          : 'Parolayı gizle',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                _PasswordStrengthIndicator(password: _password),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmation,
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (value) => value != _passwordController.text
                      ? 'Parolalar eşleşmiyor'
                      : null,
                  decoration: InputDecoration(
                    labelText: 'Parolayı Doğrula',
                    prefixIcon: const Icon(Icons.verified_user_outlined),
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmation
                          ? 'Parolayı göster'
                          : 'Parolayı gizle',
                      onPressed: () => setState(
                        () => _obscureConfirmation = !_obscureConfirmation,
                      ),
                      icon: Icon(
                        _obscureConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _selectDateOfBirth,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Doğum Tarihi',
                      prefixIcon: Icon(Icons.cake_outlined),
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      _dateOfBirth == null
                          ? 'Tarih seç'
                          : '${_dateOfBirth!.day.toString().padLeft(2, '0')}.'
                                '${_dateOfBirth!.month.toString().padLeft(2, '0')}.'
                                '${_dateOfBirth!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _province,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'İl',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                  items: TurkishLocations.provinceNames
                      .map(
                        (province) => DropdownMenuItem(
                          value: province,
                          child: Text(province),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _province = value;
                      _district = TurkishLocations.districtsFor(value).first;
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  key: ValueKey(_province),
                  initialValue: _district,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'İlçe',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  items: TurkishLocations.districtsFor(_province)
                      .map(
                        (district) => DropdownMenuItem(
                          value: district,
                          child: Text(district),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _district = value ?? _district),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _termsAccepted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      setState(() => _termsAccepted = value ?? false),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Kullanım Koşulları’nı kabul ediyorum. '),
                      TextButton(
                        onPressed: () => _showLegalDocument(
                          'Kullanım Koşulları',
                          'EcoVision hesabını yalnızca yasal ve çevreye duyarlı amaçlarla kullanacağını, topluluk kurallarına uyacağını kabul edersin.',
                        ),
                        child: const Text('Görüntüle'),
                      ),
                    ],
                  ),
                ),
                CheckboxListTile(
                  value: _privacyAccepted,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) =>
                      setState(() => _privacyAccepted = value ?? false),
                  title: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Gizlilik Politikası’nı kabul ediyorum. '),
                      TextButton(
                        onPressed: () => _showLegalDocument(
                          'Gizlilik Politikası',
                          'Kimlik ve konum verilerin yalnızca EcoVision özelliklerini sunmak, hesabını korumak ve açıkça seçtiğin topluluk işlemlerini gerçekleştirmek için işlenir.',
                        ),
                        child: const Text('Görüntüle'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isLoading ? null : _register,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Güvenli Hesap Oluştur'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _requiredName(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Bu alan zorunludur';
    if (!RegExp(r"^[\p{L} .'-]+$", unicode: true).hasMatch(normalized)) {
      return 'Geçersiz karakter içeriyor';
    }
    return null;
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  int get score => [
    password.length >= 8,
    RegExp(r'[A-Z]').hasMatch(password),
    RegExp(r'[a-z]').hasMatch(password),
    RegExp(r'[0-9]').hasMatch(password),
    RegExp(r'[^A-Za-z0-9\s]').hasMatch(password),
  ].where((valid) => valid).length;

  @override
  Widget build(BuildContext context) {
    final color = switch (score) {
      0 || 1 => Theme.of(context).colorScheme.error,
      2 || 3 => Colors.orange.shade700,
      _ => Theme.of(context).colorScheme.primary,
    };
    final label = switch (score) {
      0 || 1 => 'Zayıf',
      2 || 3 => 'Gelişiyor',
      4 => 'Güçlü',
      _ => 'Çok güçlü',
    };
    return Semantics(
      label: 'Parola gücü $label',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: score / 5,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: color,
          ),
          const SizedBox(height: 6),
          Text(
            '$label: büyük/küçük harf, rakam ve özel karakter kullan.',
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
