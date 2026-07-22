import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/api_service.dart';
import '../services/share_service.dart';

class EcoMarketScreen extends StatefulWidget {
  const EcoMarketScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<EcoMarketScreen> createState() => _EcoMarketScreenState();
}

class _EcoMarketScreenState extends State<EcoMarketScreen> {
  late Future<UserProfile> _userFuture;
  String? _purchasingItemId;

  @override
  void initState() {
    super.initState();
    _userFuture = widget.apiService.fetchCurrentUser();
  }

  Future<void> _refresh() async {
    final next = widget.apiService.fetchCurrentUser();
    setState(() {
      _userFuture = next;
    });
    await next;
  }

  Future<void> _purchase(_MarketItem item) async {
    setState(() => _purchasingItemId = item.id);
    try {
      final user = await widget.apiService.purchaseMarketItem(item.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _purchasingItemId = null;
        _userFuture = Future.value(user);
      });
      await _showPurchaseSuccess(item, user.totalPoints);
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _purchasingItemId = null);
      await _showPurchaseError(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _purchasingItemId = null);
      await _showPurchaseError(error.toString());
    }
  }

  Future<void> _showPurchaseSuccess(_MarketItem item, int points) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return AlertDialog(
          icon: Icon(Icons.check_circle, color: colors.primary, size: 48),
          title: const Text('Avatarın gelişti!'),
          content: Text(
            '${item.title} koleksiyonuna eklendi. Kalan Eko Puanın: $points.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton.icon(
              onPressed: EcoShareService.shareEcoUpgrade,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Paylaş'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPurchaseError(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
          size: 44,
        ),
        title: Text(
          message.toLowerCase().contains('yeterli')
              ? 'Yeterli puanın yok'
              : 'Satın alma başarısız',
        ),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eco-Market')),
      body: FutureBuilder<UserProfile>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _MarketError(onRetry: _refresh);
          }

          final user = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _PointsWallet(points: user.totalPoints),
                const SizedBox(height: 26),
                Text(
                  'Avatar Çerçeveleri',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tarzına uygun çerçeveyi Eko Puanlarınla aç.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 318,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _MarketItemCard(
                      item: item,
                      owned: user.ownedMarketItems.contains(item.id),
                      canAfford: user.totalPoints >= item.price,
                      loading: _purchasingItemId == item.id,
                      onPurchase: () => _purchase(item),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PointsWallet extends StatelessWidget {
  const _PointsWallet({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.onPrimary.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.stars_rounded, color: colors.onPrimary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kullanılabilir bakiye',
                  style: TextStyle(color: colors.onPrimary.withAlpha(205)),
                ),
                const SizedBox(height: 2),
                Text(
                  '$points Eko Puan',
                  style: TextStyle(
                    color: colors.onPrimary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketItemCard extends StatelessWidget {
  const _MarketItemCard({
    required this.item,
    required this.owned,
    required this.canAfford,
    required this.loading,
    required this.onPurchase,
  });

  final _MarketItem item;
  final bool owned;
  final bool canAfford;
  final bool loading;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: item.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: item.color, width: 7),
                  ),
                  child: Icon(item.icon, color: item.color, size: 48),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: owned
                  ? FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Alındı'),
                    )
                  : FilledButton(
                      onPressed: loading ? null : onPurchase,
                      child: loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              canAfford
                                  ? '${item.price} puan'
                                  : '${item.price} puan gerekli',
                            ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketError extends StatelessWidget {
  const _MarketError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.storefront_outlined, size: 52),
          const SizedBox(height: 12),
          const Text(
            'Market yüklenemedi',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Tekrar Dene')),
        ],
      ),
    );
  }
}

class _MarketItem {
  const _MarketItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String description;
  final int price;
  final IconData icon;
  final Color color;
}

const _items = [
  _MarketItem(
    id: 'streak_freeze',
    title: 'Seri Dondurucu',
    description: 'Bir gün taramayı kaçırdığında serini otomatik olarak korur.',
    price: 250,
    icon: Icons.ac_unit_rounded,
    color: Color(0xFF0087A8),
  ),
  _MarketItem(
    id: 'leaf_frame',
    title: 'Yaprak Çerçeve',
    description: 'Günlük doğa başarıları için taze yeşil çerçeve.',
    price: 100,
    icon: Icons.eco_rounded,
    color: Color(0xFF2E7D32),
  ),
  _MarketItem(
    id: 'ocean_frame',
    title: 'Okyanus Çerçeve',
    description: 'Temiz denizlerden ilham alan mavi çerçeve.',
    price: 200,
    icon: Icons.water_drop_rounded,
    color: Color(0xFF0277BD),
  ),
  _MarketItem(
    id: 'earth_frame',
    title: 'Dünya Çerçeve',
    description: 'Etki liderleri için özel gezegen çerçevesi.',
    price: 300,
    icon: Icons.public_rounded,
    color: Color(0xFF6A1B9A),
  ),
];
