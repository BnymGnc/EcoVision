import 'package:flutter/material.dart';

import '../models/scan_result.dart';

class ScanHistoryScreen extends StatelessWidget {
  const ScanHistoryScreen({required this.scans, super.key});

  final List<ScanResult> scans;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tarama Geçmişi')),
      body: scans.isEmpty
          ? const Center(child: Text('Henüz tarama geçmişin yok.'))
          : _HistoryList(entries: scans),
    );
  }
}

class _HistoryList extends StatelessWidget {
  const _HistoryList({required this.entries});

  final List<ScanResult> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: entries.length + 1,
      separatorBuilder: (_, index) =>
          index == 0 ? const SizedBox(height: 20) : const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _HistorySummary(scanCount: entries.length);
        }
        return _ScanHistoryTile(scan: entries[index - 1]);
      },
    );
  }
}

class _HistorySummary extends StatelessWidget {
  const _HistorySummary({required this.scanCount});

  final int scanCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.history_rounded, color: colors.onPrimary, size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$scanCount atık tanımlandı',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Geri dönüşüm yolculuğun, en yeniden eskiye',
                  style: TextStyle(color: colors.onPrimary.withAlpha(210)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanHistoryTile extends StatelessWidget {
  const _ScanHistoryTile({required this.scan});

  final ScanResult scan;

  @override
  Widget build(BuildContext context) {
    final color = scan.isRecyclable
        ? const Color(0xFF2E7D32)
        : const Color(0xFFEF6C00);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            scan.isRecyclable ? Icons.recycling_rounded : Icons.delete_outline,
            color: color,
          ),
        ),
        title: Text(
          scan.material,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${scan.pointsAwarded > 0 ? '+${scan.pointsAwarded} puan' : 'Puan verilmedi'} • ${_formatDate(scan.scannedAt)}',
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final sameDay =
        local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (sameDay) {
      return 'Bugün $time';
    }
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} $time';
  }
}
