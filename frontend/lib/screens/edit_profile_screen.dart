import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();

  String? _city;
  String? _district;
  String? _neighborhood;

  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await widget.apiService.fetchCurrentUser();
      if (!mounted) {
        return;
      }
      _populate(user);
      setState(() => _loading = false);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error;
        });
      }
    }
  }

  void _populate(UserProfile user) {
    _nameController.text = user.name;
    _surnameController.text = user.surname;
    _emailController.text = user.email;
    _ageController.text = user.age?.toString() ?? '';
    _city = _locations.containsKey(user.city) ? user.city : null;
    final districts = _city == null
        ? const <String, List<String>>{}
        : _locations[_city]!;
    _district = districts.containsKey(user.district) ? user.district : null;
    final neighborhoods = _district == null
        ? const <String>[]
        : districts[_district]!;
    _neighborhood = neighborhoods.contains(user.neighborhood)
        ? user.neighborhood
        : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.apiService.updateProfile(
        name: _nameController.text,
        surname: _surnameController.text,
        age: _ageController.text.trim().isEmpty
            ? null
            : int.parse(_ageController.text.trim()),
        city: _city!,
        district: _district!,
        neighborhood: _neighborhood!,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil başarıyla güncellendi.'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Profili Düzenle')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ProfileLoadError(onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.manage_accounts_outlined,
                        color: colors.onPrimaryContainer,
                        size: 36,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Şehir sıralaması ve topluluk önerileri için konumunu güncel tut.',
                          style: TextStyle(
                            color: colors.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Ad',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _surnameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Soyad',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: _required,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _emailController,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'E-posta',
                          prefixIcon: Icon(Icons.mail_outline),
                          helperText:
                              'E-posta güvenli giriş hesabına bağlıdır.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Yaş',
                          prefixIcon: Icon(Icons.cake_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final age = int.tryParse(value.trim());
                          return age == null || age < 1 || age > 120
                              ? 'Geçerli bir yaş girin'
                              : null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _city,
                        decoration: const InputDecoration(
                          labelText: 'İl',
                          hintText: 'İl seçin',
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                        items: _locations.keys
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _city = value;
                            _district = null;
                            _neighborhood = null;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Lütfen bir il seçin' : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey('district-$_city'),
                        initialValue: _district,
                        decoration: const InputDecoration(
                          labelText: 'İlçe',
                          hintText: 'Önce il, sonra ilçe seçin',
                          prefixIcon: Icon(Icons.map_outlined),
                        ),
                        items: _city == null
                            ? const <DropdownMenuItem<String>>[]
                            : _locations[_city]!.keys
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                        onChanged: _city == null
                            ? null
                            : (value) => setState(() {
                                _district = value;
                                _neighborhood = null;
                              }),
                        validator: (value) =>
                            value == null ? 'Lütfen bir ilçe seçin' : null,
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        key: ValueKey('neighborhood-$_city-$_district'),
                        initialValue: _neighborhood,
                        decoration: const InputDecoration(
                          labelText: 'Mahalle',
                          hintText: 'Önce ilçe seçin',
                          prefixIcon: Icon(Icons.home_work_outlined),
                        ),
                        items: _city == null || _district == null
                            ? const <DropdownMenuItem<String>>[]
                            : _locations[_city]![_district]!
                                  .map(
                                    (value) => DropdownMenuItem(
                                      value: value,
                                      child: Text(value),
                                    ),
                                  )
                                  .toList(),
                        onChanged: _city == null || _district == null
                            ? null
                            : (value) => setState(() => _neighborhood = value),
                        validator: (value) =>
                            value == null ? 'Lütfen bir mahalle seçin' : null,
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Değişiklikleri Kaydet'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String? _required(String? value) {
    return value == null || value.trim().isEmpty ? 'Bu alan zorunludur' : null;
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('Profil yüklenemedi.'),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}

const Map<String, Map<String, List<String>>> _locations = {
  'Şanlıurfa': {
    'Haliliye': ['Bahçelievler', 'Sırrın'],
    'Karaköprü': ['Akbayır', 'Atakent'],
  },
  'Kayseri': {
    'Melikgazi': ['Talas Yolu', 'Köşk'],
    'Kocasinan': ['Erkilet', 'Sahabiye'],
  },
  'Ankara': {
    'Çankaya': ['Bahçelievler', 'Kızılay'],
    'Keçiören': ['Etlik', 'Kalaba'],
  },
};
