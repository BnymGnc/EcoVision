import 'package:flutter/material.dart';
import '../models/doa_catalog.dart';

class DoaAreaSelection {
  const DoaAreaSelection(this.city, this.district);
  final DoaArea? city;
  final DoaArea? district;
  DoaArea? get area => district ?? city;
}

class DoaAreaPicker extends StatefulWidget {
  const DoaAreaPicker({
    required this.cities,
    this.city,
    this.district,
    super.key,
  });
  final List<DoaArea> cities;
  final DoaArea? city;
  final DoaArea? district;
  @override
  State<DoaAreaPicker> createState() => _DoaAreaPickerState();
}

class _DoaAreaPickerState extends State<DoaAreaPicker> {
  late DoaArea? city = widget.city;
  late DoaArea? district = widget.district;
  @override
  Widget build(BuildContext context) {
    final area = district ?? city;
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'İl ve ilçeye göre DOA noktaları',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const ValueKey('doa-city'),
                initialValue: city?.name,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'İl seçin'),
                items: widget.cities
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.name,
                        child: Text(
                          '${item.name} · ${item.counts['DIM'] ?? 0} makine',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (name) => setState(() {
                  city = widget.cities.firstWhere((item) => item.name == name);
                  district = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('doa-district-${city?.name}'),
                initialValue: district?.name,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'İlçe (isteğe bağlı)',
                ),
                items: (city?.districts ?? <DoaArea>[])
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.name,
                        child: Text(
                          '${item.name} · ${item.total} nokta',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: city == null
                    ? null
                    : (name) => setState(
                        () => district = city!.districts.firstWhere(
                          (item) => item.name == name,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              if (area != null)
                Text(
                  '${area.total} kayıt: ${area.counts['DIM'] ?? 0} makine (DIM), '
                  '${(area.counts['MIN'] ?? 0) + (area.counts['KIM'] ?? 0)} merkez, ${area.counts['SDM'] ?? 0} toplu iade noktası. '
                  'Adres bazlı kaynak envanteridir; canlı kabul garantisi değildir. Malzeme ve tür filtreleri ayrıca uygulanır.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: city == null
                    ? null
                    : () => Navigator.pop(
                        context,
                        DoaAreaSelection(city, district),
                      ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Haritada göster'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, const DoaAreaSelection(null, null)),
                child: const Text('İl / ilçe filtresini kaldır'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
