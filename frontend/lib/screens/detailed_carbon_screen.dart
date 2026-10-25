import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../widgets/premium_ui.dart';

class DetailedCarbonScreen extends StatefulWidget {
  const DetailedCarbonScreen({required this.apiService, super.key});
  final ApiService apiService;
  @override
  State<DetailedCarbonScreen> createState() => _DetailedCarbonScreenState();
}

class _DetailedCarbonScreenState extends State<DetailedCarbonScreen> {
  final _form = GlobalKey<FormState>();
  final _electricity = TextEditingController();
  final _fuel = TextEditingController();
  int _household = 1;
  bool _annual = false;
  bool _busy = false;
  String _fuelType = 'UNKNOWN';
  Map<String, dynamic>? _assessment;
  late Future<List<Map<String, dynamic>>> _actions;

  @override
  void initState() {
    super.initState();
    _actions = widget.apiService.fetchWasteActions();
  }

  @override
  void dispose() {
    _electricity.dispose();
    _fuel.dispose();
    super.dispose();
  }

  String? _validate(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = double.tryParse(text.replaceAll(',', '.'));
    return value == null || !value.isFinite || value < 0 || value > 1000000
        ? 'Geçerli, negatif olmayan bir değer gir.'
        : null;
  }

  double? _monthly(TextEditingController controller) {
    final value = double.tryParse(controller.text.replaceAll(',', '.'));
    return value == null ? null : value / (_annual ? 12 : 1);
  }

  Future<void> _calculate() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final response = await widget.apiService.assessCarbon({
        'monthlyElectricityKwh': _monthly(_electricity),
        'householdMembers': _household,
        'fuelType': _fuelType,
        'monthlyFuelLitres': _monthly(_fuel),
      });
      if (!mounted) return;
      setState(
        () => _assessment = Map<String, dynamic>.from(
          response['assessment'] as Map,
        ),
      );
      EcoHaptics.light();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hesabın kaydedildi.')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editMass(Map<String, dynamic> action) async {
    final controller = TextEditingController(
      text: ((action['massKg'] as num) * 1000).toStringAsFixed(1),
    );
    final key = GlobalKey<FormState>();
    final grams = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tartılan kütleyi düzelt'),
        content: Form(
          key: key,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Gram'),
            validator: (text) {
              final value = double.tryParse((text ?? '').replaceAll(',', '.'));
              return value == null ||
                      !value.isFinite ||
                      value <= 0 ||
                      value > 1000000
                  ? '1.000.000 grama kadar pozitif bir değer gir.'
                  : null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(
                  context,
                  double.parse(controller.text.replaceAll(',', '.')),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    // The route may still be animating while the dialog's field is mounted.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (grams == null || !mounted) return;
    try {
      await widget.apiService.updateWasteAction(
        (action['id'] as num).toInt(),
        grams / 1000,
      );
      if (mounted) {
        setState(() => _actions = widget.apiService.fetchWasteActions());
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final texts = Theme.of(context).textTheme;
    final result = _assessment;
    return Scaffold(
      appBar: AppBar(title: const Text('Karbon ve Eylemlerim')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Tüketimini ölç', style: texts.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Faturandaki ve yakıt kaydındaki değerleri kullan. Bilmediğin alanı boş bırak.',
            style: texts.bodyMedium,
          ),
          const SizedBox(height: 16),
          Form(
            key: _form,
            child: GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Aylık')),
                      ButtonSegment(value: true, label: Text('Yıllık')),
                    ],
                    selected: {_annual},
                    onSelectionChanged: (values) =>
                        setState(() => _annual = values.first),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _electricity,
                    validator: _validate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Hane elektrik tüketimi (kWh)',
                      prefixIcon: Icon(Icons.bolt_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    initialValue: _household,
                    decoration: const InputDecoration(
                      labelText: 'Hanede yaşayan kişi sayısı',
                    ),
                    items: [
                      for (var i = 1; i <= 12; i++)
                        DropdownMenuItem(value: i, child: Text('$i kişi')),
                    ],
                    onChanged: (value) =>
                        setState(() => _household = value ?? 1),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _fuelType,
                    decoration: const InputDecoration(
                      labelText: 'Kişisel araç yakıtı',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'UNKNOWN',
                        child: Text('Bilgi yok'),
                      ),
                      DropdownMenuItem(
                        value: 'NONE',
                        child: Text('Benzin/dizel kullanmıyorum'),
                      ),
                      DropdownMenuItem(value: 'PETROL', child: Text('Benzin')),
                      DropdownMenuItem(value: 'DIESEL', child: Text('Dizel')),
                    ],
                    onChanged: (value) =>
                        setState(() => _fuelType = value ?? 'UNKNOWN'),
                  ),
                  if (_fuelType == 'PETROL' || _fuelType == 'DIESEL') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _fuel,
                      validator: _validate,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Kişisel yakıt tüketimi (litre)',
                        prefixIcon: Icon(Icons.local_gas_station_outlined),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _calculate,
                      icon: const Icon(Icons.calculate_outlined),
                      label: Text(
                        _busy ? 'Hesaplanıyor...' : 'Hesapla ve Kaydet',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 20),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bilinen tüketimlerin tahmini',
                    style: texts.titleMedium,
                  ),
                  Text(
                    '${(result['monthlyKnownKg'] as num).toStringAsFixed(1)} kg / ay',
                    style: texts.headlineMedium?.copyWith(
                      color: colors.primary,
                    ),
                  ),
                  Text(
                    '${((result['annualKnownKg'] as num) / 1000).toStringAsFixed(2)} ton / yıl',
                  ),
                  const SizedBox(height: 12),
                  for (final entry
                      in (result['annualByCategory'] as Map).entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        entry.key == 'electricity'
                            ? 'Hane elektrik payın'
                            : 'Araç yakıtı',
                      ),
                      trailing: Text(
                        '${(entry.value as num).toStringAsFixed(1)} kg/yıl',
                      ),
                    ),
                  Text(
                    'Bu toplama dahil olmayanlar: ${(result['missingCategories'] as List).join(', ')}.',
                  ),
                  ExpansionTile(
                    title: const Text('Yöntem ve kaynaklar'),
                    children: [
                      Text(result['scope'].toString()),
                      for (final factor in result['factors'] as List)
                        ListTile(
                          title: Text(
                            '${factor['id']}: ${factor['value']} ${factor['unit']}',
                          ),
                          subtitle: Text(
                            '${factor['year']} · ${factor['geography']}',
                          ),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => launchUrl(
                            Uri.parse(factor['sourceUrl'].toString()),
                            mode: LaunchMode.externalApplication,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text('Atık eylemlerin', style: texts.titleLarge),
          const Text(
            'Beyan edilen eylemler kişisel tüketim hesabından ayrı tutulur.',
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _actions,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text(
                  'Eylemler yüklenemedi. Daha sonra tekrar dene.',
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (snapshot.data!.isEmpty) {
                return const ListTile(
                  leading: Icon(Icons.eco_outlined),
                  title: Text('Henüz eylem kaydı yok'),
                  subtitle: Text(
                    'Tarama sonucundan gerçekleştirdiğin ayrıştırmayı kaydedebilirsin.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final action in snapshot.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.recycling),
                      title: Text(
                        '${action['material']} · ${action['massKg']} kg',
                      ),
                      subtitle: Text(
                        action['estimatedDifferenceKg'] == null
                            ? 'Etki hesaplanamadı'
                            : 'Tahmini fark: ${(action['estimatedDifferenceKg'] as num).toStringAsFixed(3)} kg CO₂e · Kullanıcı beyanı',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Gramajı düzelt',
                            onPressed: () => _editMass(action),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Kaydı sil',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await widget.apiService.deleteWasteAction(
                                  (action['id'] as num).toInt(),
                                );
                                if (mounted) {
                                  setState(
                                    () => _actions = widget.apiService
                                        .fetchWasteActions(),
                                  );
                                }
                              } catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$error')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
