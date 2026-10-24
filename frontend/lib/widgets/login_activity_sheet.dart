import 'package:flutter/material.dart';

import '../models/login_activity.dart';
import '../services/api_service.dart';
import 'premium_ui.dart';

class LoginActivitySheet extends StatefulWidget {
  const LoginActivitySheet({required this.apiService, this.summary, super.key});
  final ApiService apiService;
  final LoginStreakSummary? summary;
  @override
  State<LoginActivitySheet> createState() => _LoginActivitySheetState();
}

class _LoginActivitySheetState extends State<LoginActivitySheet> {
  late Future<LoginActivityMonth> _future;
  DateTime? _requestedMonth;

  @override
  void initState() {
    super.initState();
    final today = widget.summary?.today;
    _requestedMonth = today == null
        ? null
        : DateTime.utc(today.year, today.month);
    _future = _load();
  }

  Future<LoginActivityMonth> _load() async {
    try {
      final month = _requestedMonth;
      return await widget.apiService.fetchLoginHistory(
        month: month == null ? null : loginDateKey(month).substring(0, 7),
      );
    } on ApiException catch (error) {
      final summary = widget.summary;
      // During a staggered deployment, label the old API's seven-day window
      // rather than manufacturing a full month of historical activity.
      if (error.statusCode != 404 || summary == null) rethrow;
      final month = DateTime.utc(summary.today.year, summary.today.month);
      if (_requestedMonth != null && _requestedMonth != month) rethrow;
      return LoginActivityMonth(
        month: month,
        today: summary.today,
        loginDates: summary.lastSevenDays
            .where((day) => day.startsWith(loginDateKey(month).substring(0, 7)))
            .toSet(),
        partial: true,
      );
    }
  }

  void _moveMonth(LoginActivityMonth current, int offset) {
    EcoHaptics.selection();
    setState(() {
      _requestedMonth = DateTime.utc(
        current.month.year,
        current.month.month + offset,
      );
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EcoSheetHandle(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Giriş günlerin',
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Kapat',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  if (widget.summary case final summary?)
                    Text(
                      'Güncel seri: ${summary.currentStreak} gün · En uzun: ${summary.longestStreak} gün',
                      style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 20),
                  FutureBuilder<LoginActivityMonth>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 280,
                          child: EcoShimmerList(itemCount: 3),
                        );
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                size: 64,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Giriş günlerin yüklenemedi.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                onPressed: () => setState(() {
                                  _future = _load();
                                }),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Tekrar Dene'),
                              ),
                            ],
                          ),
                        );
                      }
                      final data = snapshot.requireData;
                      final currentMonth = DateTime.utc(
                        data.today.year,
                        data.today.month,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Önceki ay',
                                onPressed: data.partial
                                    ? null
                                    : () => _moveMonth(data, -1),
                                icon: const Icon(Icons.chevron_left_rounded),
                              ),
                              Expanded(
                                child: Text(
                                  '${_months[data.month.month - 1]} ${data.month.year}',
                                  textAlign: TextAlign.center,
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Sonraki ay',
                                onPressed:
                                    data.partial ||
                                        !data.month.isBefore(currentMonth)
                                    ? null
                                    : () => _moveMonth(data, 1),
                                icon: const Icon(Icons.chevron_right_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              for (final day in const [
                                'Pzt',
                                'Sal',
                                'Çar',
                                'Per',
                                'Cum',
                                'Cmt',
                                'Paz',
                              ])
                                Expanded(
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        day,
                                        style: text.labelSmall?.copyWith(
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _MonthGrid(data: data),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 16,
                            runSpacing: 10,
                            children: [
                              _Legend(
                                color: colors.primary,
                                label: 'Giriş yapıldı',
                                filled: true,
                              ),
                              _Legend(
                                color: colors.outline,
                                label: 'Kayıt yok',
                                filled: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            data.partial
                                ? 'Bu görünüm yalnızca son yedi günün kayıtlarını içerir.'
                                : '${data.loginDates.length} gün giriş kaydı var. Günler Türkiye saatine göre gösterilir.',
                            style: text.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _months = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.data});
  final LoginActivityMonth data;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final offset = data.month.weekday - 1;
    final days = DateTime.utc(data.month.year, data.month.month + 1, 0).day;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: offset + days,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 5,
        crossAxisSpacing: 5,
      ),
      itemBuilder: (context, index) {
        if (index < offset) return const SizedBox.shrink();
        final day = DateTime.utc(
          data.month.year,
          data.month.month,
          index - offset + 1,
        );
        final active = data.loginDates.contains(loginDateKey(day));
        final today = day == data.today;
        final future = day.isAfter(data.today);
        return Semantics(
          key: ValueKey('login-day-${loginDateKey(day)}'),
          label:
              '${day.day} ${_months[day.month - 1]} ${day.year}, ${active
                  ? 'giriş yapıldı'
                  : future
                  ? 'gelecek gün'
                  : 'giriş kaydı yok'}${today ? ', bugün' : ''}',
          child: ExcludeSemantics(
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? colors.primary : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: today
                      ? colors.primary
                      : colors.outlineVariant.withValues(alpha: 0.4),
                  width: today ? 2 : 1,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: active
                        ? colors.onPrimary
                        : future
                        ? colors.outline
                        : colors.onSurface,
                    fontWeight: active || today
                        ? FontWeight.w900
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.color,
    required this.label,
    required this.filled,
  });
  final Color color;
  final String label;
  final bool filled;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        filled ? Icons.circle : Icons.circle_outlined,
        color: color,
        size: 13,
      ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}
