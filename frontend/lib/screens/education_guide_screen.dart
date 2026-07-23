import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WasteGuideItem {
  const WasteGuideItem({
    required this.title,
    required this.subtitle,
    required this.fact,
    required this.aiTip,
    required this.journey,
    required this.upcycle,
  });

  final String title;
  final String subtitle;
  final String fact;
  final String aiTip;
  final String journey;
  final String upcycle;
}

class WasteGuideScreen extends StatefulWidget {
  const WasteGuideScreen({super.key});

  @override
  State<WasteGuideScreen> createState() => _WasteGuideScreenState();
}

// Eski navigasyon çağrılarını kırmadan yeni rehberi devreye alır.
class EducationGuideScreen extends WasteGuideScreen {
  const EducationGuideScreen({super.key});
}

class _WasteGuideScreenState extends State<WasteGuideScreen> {
  int? _expandedIndex;

  void _toggle(int index) {
    final expanding = _expandedIndex != index;
    if (expanding) {
      HapticFeedback.selectionClick();
    }
    setState(() => _expandedIndex = expanding ? index : null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gelişmiş Atık Rehberi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: wasteGuideItems.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return const _GuideHeader();
            }
            final itemIndex = index - 1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RepaintBoundary(
                child: _WasteGuideCard(
                  item: wasteGuideItems[itemIndex],
                  visual: _guideVisuals[itemIndex],
                  expanded: _expandedIndex == itemIndex,
                  onTap: () => _toggle(itemIndex),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GuideHeader extends StatelessWidget {
  const _GuideHeader();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.auto_stories_outlined,
              color: colors.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Atığın hikâyesini keşfet',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Doğadaki etkisi, yapay zeka ipuçları ve yeni kullanım fikirleri.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
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

class _WasteGuideCard extends StatelessWidget {
  const _WasteGuideCard({
    required this.item,
    required this.visual,
    required this.expanded,
    required this.onTap,
  });

  final WasteGuideItem item;
  final _GuideVisual visual;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tint = Color.alphaBlend(
      visual.color.withValues(alpha: expanded ? 0.14 : 0.08),
      colors.surface,
    );
    final end = Color.alphaBlend(
      colors.secondary.withValues(alpha: 0.05),
      colors.surface,
    );

    return Semantics(
      button: true,
      expanded: expanded,
      label: item.title,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [tint, end],
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: expanded
                    ? visual.color.withValues(alpha: 0.48)
                    : colors.outlineVariant.withValues(alpha: 0.75),
                width: expanded ? 1.4 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(
                    alpha: expanded ? 0.12 : 0.06,
                  ),
                  blurRadius: expanded ? 24 : 12,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _CardHeader(
                        item: item,
                        visual: visual,
                        expanded: expanded,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeInOut,
                        alignment: Alignment.topCenter,
                        child: expanded
                            ? _ExpandedContent(item: item, visual: visual)
                            : const SizedBox(width: double.infinity),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.item,
    required this.visual,
    required this.expanded,
  });

  final WasteGuideItem item;
  final _GuideVisual visual;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: visual.color.withValues(alpha: expanded ? 0.22 : 0.13),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(visual.icon, color: visual.color, size: 31),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AnimatedRotation(
          turns: expanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOut,
          child: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: visual.color,
            size: 28,
          ),
        ),
      ],
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({required this.item, required this.visual});

  final WasteGuideItem item;
  final _GuideVisual visual;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Divider(
          height: 1,
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 4),
        _GuideSection(text: item.fact, accent: visual.color),
        _GuideSection(text: item.aiTip, accent: const Color(0xFF3B82C4)),
        _GuideSection(text: item.journey, accent: const Color(0xFF65736A)),
        _GuideSection(
          text: item.upcycle,
          accent: item.upcycle.contains('Önemli Uyarı')
              ? Theme.of(context).colorScheme.error
              : const Color(0xFFD18822),
        ),
      ],
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final separator = text.indexOf(':');
    final heading = separator == -1 ? text : text.substring(0, separator + 1);
    final body = separator == -1 ? '' : text.substring(separator + 1).trim();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    body,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideVisual {
  const _GuideVisual({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

const _guideVisuals = <_GuideVisual>[
  _GuideVisual(icon: Icons.local_drink_outlined, color: Color(0xFF2374AB)),
  _GuideVisual(icon: Icons.wine_bar_outlined, color: Color(0xFF00897B)),
  _GuideVisual(icon: Icons.description_outlined, color: Color(0xFF9A6B16)),
  _GuideVisual(icon: Icons.hardware_outlined, color: Color(0xFF586875)),
  _GuideVisual(icon: Icons.devices_other_outlined, color: Color(0xFF7652A8)),
  _GuideVisual(icon: Icons.inventory_2_outlined, color: Color(0xFF20889A)),
  _GuideVisual(icon: Icons.oil_barrel_outlined, color: Color(0xFFCB7414)),
  _GuideVisual(icon: Icons.checkroom_outlined, color: Color(0xFFC45B65)),
  _GuideVisual(
    icon: Icons.energy_savings_leaf_outlined,
    color: Color(0xFF3F8A54),
  ),
  _GuideVisual(
    icon: Icons.health_and_safety_outlined,
    color: Color(0xFFC53B3F),
  ),
];

const wasteGuideItems = <WasteGuideItem>[
  WasteGuideItem(
    title: 'Plastik Atıklar (PET, HDPE, PVC, PP)',
    subtitle: 'Doğada Ömrü: 100-1000 Yıl | Puan: Orta',
    fact:
        '🌍 Bunu Biliyor Muydun?: Plastikler asla tamamen yok olmaz, gözle görülmeyen mikroplastiklere bölünürler. Bugün okyanuslardaki mikroplastik sayısı, galaksimizdeki yıldız sayısından fazladır.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Şeffaf şişeleri taratırken ışık yansımasından kaçın. Kamerayı etikete veya kapağa odaklamak, yapay zekanın "Plastik" güven skorunu %95\'in üzerine çıkarır.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Tesislerde "Granül" adı verilen mercimek büyüklüğünde parçalara kırılırlar. Bu granüller eritilerek sentetik elyafa (polar montlar), plastik borulara veya yeni poşetlere dönüşür.',
    upcycle:
        '💡 İleri Dönüşüm (Kendin Yap): Şampuan veya deterjan kutularını (HDPE) atmadan önce maket bıçağıyla keserek çalışma masan için çok bölmeli, şık düzenleyiciler yapabilirsin.',
  ),
  WasteGuideItem(
    title: 'Cam Atıklar',
    subtitle: 'Doğada Ömrü: 4.000 Yıl | Puan: Yüksek',
    fact:
        '🌍 Bunu Biliyor Muydun?: Cam kum, soda ve kireçtaşından yapılır. Hiçbir kalite kaybı yaşamadan sonsuz defa geri dönüştürülebilir.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Cam yüzeyler kamerada parlama (glare) yapar. Güneşi veya lambayı arkana alarak, camın silüetini ve rengini netleştirecek bir açıyla tarama yap.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Renklerine (Şeffaf, Yeşil, Kahverengi) göre ayrılırlar. Kırılıp 1500°C\'de eritilerek yepyeni şişe ve kavanozlara kalıplanırlar.',
    upcycle:
        '💡 İleri Dönüşüm (Kendin Yap): Boş soda şişelerinin dışını akrilik boya veya hasır iple sararak modern vazolar üretebilirsin.',
  ),
  WasteGuideItem(
    title: 'Kağıt ve Karton Atıklar',
    subtitle: 'Doğada Ömrü: 2-6 Ay | Puan: Düşük',
    fact:
        '🌍 Bunu Biliyor Muydun?: Kurtarılan her 1 ton kağıt, 17 ağacın kesilmesini önler. Ancak kağıt sonsuza kadar dönüştürülemez, 5-7 dönüşümden sonra lifleri kısalır ve ömrünü tamamlar.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Buruşturulmuş bir kağıt kamera tarafından "organik atık" sanılabilir. Taratmadan önce kağıdı elinle düzelt. Yağlı pizza kutuları dönüştürülemez!',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Mikserlerde suyla "hamur" (pulp) haline getirilir. İçindeki mürekkep temizlenir, sıcak silindirlerde preslenip kurutularak dev bobinlere sarılır.',
    upcycle:
        '💡 İleri Dönüşüm (Kendin Yap): Ayakkabı kutularını hediye kağıtlarıyla kaplayarak şık saklama kutularına veya kedi/köpek evlerine dönüştürebilirsin.',
  ),
  WasteGuideItem(
    title: 'Metal Atıklar (Alüminyum, Çelik)',
    subtitle: 'Doğada Ömrü: 10-500 Yıl | Puan: Yüksek',
    fact:
        '🌍 Bunu Biliyor Muydun?: Bir alüminyum kutuyu dönüştürmek, sıfırdan üretmeye kıyasla %95 enerji tasarrufu sağlar. Mıknatıs yapışıyorsa çelik, yapışmıyorsa alüminyumdur.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Konserve kutularının silindirik yapısı yapay zeka için tanıdıktır. Ancak metal ezilmişse, kameranın tanıması için hafif çapraz bir açıdan tarama yap.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Dev fırınlarda eritilerek devasa metal bloklar (ingot) halinde dökülür. O bloklar uçak gövdesinden bisiklet jantına kadar her şeye dönüşebilir.',
    upcycle:
        '💡 İleri Dönüşüm (Kendin Yap): Boş konserve kutularının dışını jüt ipi (hasır) ile silikonlayarak sarıp, banyon için şık pamukluklar veya fırçalıklar yapabilirsin.',
  ),
  WasteGuideItem(
    title: 'Elektronik Atıklar (E-Atık)',
    subtitle: 'Doğada Ömrü: Yüzyıllarca Zehir Salar | Puan: Çok Yüksek',
    fact:
        '🌍 Bunu Biliyor Muydun?: 1 ton cep telefonundan elde edilen altın miktarı, 1 ton altın cevherinden elde edilenden fazladır. Çöpe atılırlarsa toprağı zehirlerler.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Pilleri, kabloları veya eski fareleri tararken arka planın desensiz ve sade olmasına özen göster. Karmaşık zeminler yapay zekayı yanıltır.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Özel tesislerde parçalarına ayrılırlar. Devre kartlarındaki altın ve bakır ayrıştırılır, pillerdeki zehirli asitler nötralize edilir.',
    upcycle:
        '💡 İleri Dönüşüm (Kendin Yap): Bozulan klavyelerdeki tuşları dikkatlice söküp altlarına küçük mıknatıslar yapıştırarak buzdolabın için teknolojik magnetler yapabilirsin.',
  ),
  WasteGuideItem(
    title: 'Kompozit Atıklar (Tetra Pak)',
    subtitle: 'Doğada Ömrü: 50-100 Yıl | Puan: Orta',
    fact:
        '🌍 Bunu Biliyor Muydun?: Süt ve meyve suyu kutuları sadece kağıt değildir. İçlerinde %75 kağıt, %20 plastik ve %5 alüminyum bulunur. Bu yüzden dönüştürülmeleri çok zordur.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Yapay zeka bu kutuları üzerindeki marka grafiklerinden tanır. Taratırken pipet deliğini veya kapağını da kameraya göstermek doğruluğu artırır.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Dev kazanlarda şiddetli şekilde döndürülerek katmanları ayrılır. Kağıt peçete olurken, plastik/alüminyum karışımı park banklarına dönüştürülür.',
    upcycle:
        '💡 İleri Dönüşüm (Kendin Yap): Süt kutusunu yan yatırıp üstünü keserek, balkonunda kendi tohumlarını filizlendirmek için su geçirmez fidelikler (saksılar) yapabilirsin.',
  ),
  WasteGuideItem(
    title: 'Bitkisel Atık Yağlar',
    subtitle: 'Doğada Ömrü: Suyu Zehirler | Puan: Destansı',
    fact:
        '🌍 Bunu Biliyor Muydun?: Lavaboya döktüğün sadece 1 litre kızartma yağı, 1 Milyon litre temiz içme suyunu kirletir. Ayrıca kanalizasyonda devasa yağ dağları oluşturur.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Atık yağı şeffaf bir pet şişede biriktir. Yapay zekaya taratırken, sıvının rengini görebilmesi için ışıklı bir ortamda şişenin tümünü okut.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Toplanan yağlar özel tesislerde filtrelenir ve kimyasal bir reaksiyondan (esterleşme) geçirilerek temiz enerji olan Biyodizel yakıta dönüştürülür.',
    upcycle:
        '💡 Önemli Uyarı: Asla lavaboya dökme! Soğumasını bekle, bir şişeye aktar ve belediyelerin atık yağ kumbaralarına teslim et.',
  ),
  WasteGuideItem(
    title: 'Tekstil ve Kumaş Atıkları',
    subtitle: 'Doğada Ömrü: 20-200 Yıl | Puan: Yüksek',
    fact:
        '🌍 Bunu Biliyor Muydun?: Sadece bir pamuklu tişört üretmek için 2.700 litre su (bir insanın 2.5 yıllık içme suyu) harcanır. Moda endüstrisi dünyayı hızla kirletiyor.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Kumaşı düz bir zemine sererek tarat. Eğer bu eski bir tişörtse, yaka ve kol kısımlarını göstermek onun düz bir örtü sanılmasını engeller.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Giyilemeyecek durumdaki kıyafetler dev makinelerde parçalanarak elyaf haline getirilir. Bu elyaflar otomobil yalıtımında veya temizlik bezi olarak kullanılır.',
    upcycle:
        '💡 İleri Dönüşüm (Kendin Yap): Eski tişörtleri ince şeritler halinde kesip örerek harika bez çantalar, paspaslar veya evcil hayvanın için çiğneme oyuncakları yapabilirsin.',
  ),
  WasteGuideItem(
    title: 'Organik Atıklar (Evsel Atıklar)',
    subtitle: 'Doğada Ömrü: 1 Hafta-6 Ay | Puan: Düşük',
    fact:
        '🌍 Bunu Biliyor Muydun?: Çöplüklere giden atıkların %50\'si organik atıklardır. Çöp dağlarında oksijensiz kaldıklarında metan gazı üreterek küresel ısınmayı tetiklerler.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Kamera meyve kabuklarını (muz, elma) kolayca tanır. Ancak çamur kıvamına gelmiş karışık atıkları tanımak zordur; formunu kaybetmeden tara.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Kompost tesislerinde oksijen ve bakterilerle çürütülerek çiftçiler için "kara altın" denilen organik gübreye veya elektrik için biyogaza dönüşür.',
    upcycle:
        '💡 İleri Dönüşüm (Kendin Yap): Kahve telvelerini biraz zeytinyağı ile karıştırarak cildin için harika bir doğal peeling yapabilirsin. Yumurta kabukları da saksı bitkilerine kalsiyum verir!',
  ),
  WasteGuideItem(
    title: 'Tehlikeli ve Tıbbi Atıklar',
    subtitle: 'Sistem Uyarısı: Kabul Edilmez | Puan: 0',
    fact:
        '🌍 Bunu Biliyor Muydun?: Şırıngalar, tarihi geçmiş ilaçlar veya boya tenekeleri normal geri dönüşüme dahil edilemez. Bu atıklar özel bertaraf tesislerinde yüksek ısıda yakılır.',
    aiTip:
        '📸 Yapay Zeka Tarama İpucu: Sistem bir ilaç kutusu veya şırınga algıladığında puan vermez, ekranı kırmızıya çevirerek tehlike uyarısı verir.',
    journey:
        '🏭 Geri Dönüşüm Serüveni: Geri dönüştürülemezler. İzole edilmiş fırınlarda çevreye zarar vermeden imha edilirler.',
    upcycle:
        '💡 Önemli Uyarı: Bu atıkları geri dönüşüm kutusuna ATMAYIN. Eczanelerdeki atık ilaç kutularına veya belediyenin tehlikeli atık toplama noktalarına teslim edin.',
  ),
];
