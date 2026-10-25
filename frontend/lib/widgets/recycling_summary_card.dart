import 'package:flutter/material.dart';
import 'premium_ui.dart';

class RecyclingSummaryCard extends StatelessWidget {
  const RecyclingSummaryCard({
    required this.summary,
    required this.loading,
    required this.failed,
    required this.onRetry,
    super.key,
  });

  final Map<String, dynamic>? summary;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  static num? _number(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value : null;

  static String _amount(num value, int digits) =>
      value.toStringAsFixed(digits).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = summary;
    final scans = _number(data?['recyclableScanCount'])?.toInt();
    final modeled = _number(data?['modeledScanCount'])?.toInt();
    final kg = _number(data?['potentialKgCo2e']);
    final available = scans != null && modeled != null && kg != null;
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.recycling_rounded, color: colors.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Toplam geri dönüşüm',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (available)
                IconButton(
                  tooltip: 'Hesaplama varsayımları',
                  onPressed: () => _showDetails(context, data!),
                  icon: const Icon(Icons.info_outline),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (loading)
            const LinearProgressIndicator()
          else if (failed)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Geri dönüşüm özeti yüklenemedi. Tekrar dene'),
            )
          else if (!available)
            const Text('Bu özet için sunucu güncellemesi gerekiyor.')
          else ...[
            Text(
              '$scans ayrıştırma taraması',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_amount(kg, 3)} kg CO₂e potansiyeli',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '$modeled tarama için örnek gramajlarla hesaplanan geri dönüşüm senaryosu. '
              'Tartılmış atık veya gerçekleşmiş karbon tasarrufu değildir.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            if (scans > modeled)
              Text(
                '${scans - modeled} taramanın malzemesi/katsayısı belirsiz; CO₂e toplamına eklenmedi.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _showDetails(
    BuildContext context,
    Map<String, dynamic> data,
  ) => showEcoGlassSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Geri dönüşüm potansiyeli',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Her benzersiz, ödüllendirilmiş ayrıştırma taraması bir kez sayılır. '
              'Bir fotoğraftaki nesnelerin adedi veya kütlesi ölçülmez. '
              'Eski kayıtlarda görsel kimliği yoksa tekrarlar ayırt edilemez.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Örnek senaryo: PET 25 g, cam 200 g, alüminyum 15 g / tarama. '
              'Bu gramajlar uygulama varsayımıdır; gerçek nesnenin ağırlığı değildir. '
              'Genel plastik ve metal, PET/alüminyum sayılmaz.',
            ),
            for (final part in (data['materials'] as List? ?? const []))
              if (part is Map &&
                  _number(part['scanCount']) != null &&
                  _number(part['potentialKgCo2e']) != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (part['material']) {
                    'pet' => 'PET',
                    'glass' => 'Cam',
                    'aluminum' => 'Alüminyum',
                    _ => 'Diğer',
                  }),
                  subtitle: Text('${part['scanCount']} tarama'),
                  trailing: Text(
                    '${_amount(part['potentialKgCo2e'] as num, 3)} kg CO₂e',
                  ),
                ),
            const SizedBox(height: 12),
            const Text(
              'Hesap: tarama sayısı × örnek kütle × malzeme katsayısı. '
              'EPA WARM v13 ABD depolama → geri dönüşüm senaryosudur; '
              'Türkiye saha ölçümü, DOA iade teyidi veya karbon kredisi değildir. '
              'Yıllık karbon ayak izinden otomatik düşülmez.',
            ),
            const SizedBox(height: 10),
            Text(
              'Sürüm: ${data['factorVersion'] ?? 'Bilinmiyor'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    ),
  );
}
