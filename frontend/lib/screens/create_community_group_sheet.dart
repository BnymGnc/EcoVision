import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/turkey_locations.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';

class CreateCommunityGroupSheet extends StatefulWidget {
  const CreateCommunityGroupSheet({
    required this.apiService,
    required this.onCreated,
    super.key,
  });

  final ApiService apiService;
  final VoidCallback onCreated;

  @override
  State<CreateCommunityGroupSheet> createState() =>
      _CreateCommunityGroupSheetState();
}

class _CreateCommunityGroupSheetState extends State<CreateCommunityGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _neighborhood = TextEditingController();
  final _joinCode = TextEditingController();
  final _picker = ImagePicker();
  String? _city;
  String? _district;
  int _memberLimit = 20;
  bool _saving = false;
  bool _passwordProtected = false;
  Uint8List? _coverBytes;
  String? _coverName;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _neighborhood.dispose();
    _joinCode.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    await EcoHaptics.light();
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      _showError('Kapak fotoğrafı 5 MB altında olmalıdır.');
      return;
    }
    if (mounted) {
      setState(() {
        _coverBytes = bytes;
        _coverName = image.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await EcoHaptics.light();
    setState(() => _saving = true);
    try {
      await widget.apiService.createCommunityGroup(
        name: _name.text,
        description: _description.text,
        city: _city!,
        district: _district!,
        neighborhood: _neighborhood.text,
        memberLimit: _memberLimit,
        joinCode: _passwordProtected ? _joinCode.text : null,
        privateGroup: _passwordProtected,
        coverBytes: _coverBytes,
        coverFileName: _coverName,
      );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const EcoSheetHandle(),
              Text(
                'Yeni Grup',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Topluluğunu oluştur, üyelerini bir araya getir.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              InkWell(
                onTap: _saving ? null : _pickCover,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _coverBytes == null
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined, size: 38),
                            SizedBox(height: 8),
                            Text('Grup kapak fotoğrafı'),
                          ],
                        )
                      : Image.memory(_coverBytes!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Grup adı',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
                validator: (value) => (value ?? '').trim().length < 3
                    ? 'Grup adı en az 3 karakter olmalıdır'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Grubun amacı',
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value ?? '').trim().length < 10
                    ? 'Açıklama en az 10 karakter olmalıdır'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _city,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'İl',
                  hintText: 'İl seçin',
                ),
                items: TurkishLocations.provinceNames
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _city = value;
                  _district = null;
                }),
                validator: (value) =>
                    value == null ? 'Lütfen bir il seçin' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(_city),
                initialValue: _district,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'İlçe',
                  hintText: 'Önce il, sonra ilçe seçin',
                ),
                items: _city == null
                    ? const <DropdownMenuItem<String>>[]
                    : TurkishLocations.districtsFor(_city!)
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                onChanged: _city == null
                    ? null
                    : (value) => setState(() => _district = value),
                validator: (value) =>
                    value == null ? 'Lütfen bir ilçe seçin' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _neighborhood,
                decoration: const InputDecoration(
                  labelText: 'Mahalle (isteğe bağlı)',
                  prefixIcon: Icon(Icons.holiday_village_outlined),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _memberLimit,
                decoration: const InputDecoration(labelText: 'Üye sınırı'),
                items: const [10, 20, 50, 100, 200]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value kişi'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _memberLimit = value!),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _passwordProtected,
                onChanged: (value) => setState(() {
                  _passwordProtected = value;
                  if (!value) _joinCode.clear();
                }),
                secondary: const Icon(Icons.lock_outline_rounded),
                title: const Text('Şifreli grup'),
                subtitle: const Text(
                  'Katılımcılar doğru şifreyi girerek doğrudan katılır.',
                ),
              ),
              if (_passwordProtected) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _joinCode,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Grup şifresi',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (!_passwordProtected) return null;
                    if ((value ?? '').trim().length < 4) {
                      return 'Grup şifresi en az 4 karakter olmalıdır';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: const Text('Grubu Oluştur'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
