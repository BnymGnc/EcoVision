import 'package:flutter/material.dart';

class EducationGuideScreen extends StatefulWidget {
  const EducationGuideScreen({super.key});

  @override
  State<EducationGuideScreen> createState() => _EducationGuideScreenState();
}

class _EducationGuideScreenState extends State<EducationGuideScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtered = _categories.where((category) {
      final searchable = [
        category.title,
        category.summary,
        ...category.rules,
      ].join(' ').toLowerCase();
      return searchable.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Waste Encyclopedia')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: colors.onPrimaryContainer,
                  size: 40,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Know before you throw',
                        style: TextStyle(
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.w900,
                          fontSize: 19,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Fast, practical guidance for everyday waste.',
                        style: TextStyle(
                          color: colors.onPrimaryContainer.withAlpha(205),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search plastics, oils, electronics...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _query = '');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 54),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 52,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No waste guide matches that search.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            for (final category in filtered) ...[
              _GuideTile(category: category),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.category});

  final _WasteCategory category;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: category.color.withAlpha(28),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(category.icon, color: category.color),
        ),
        title: Text(
          category.title,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(category.summary),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: colors.outlineVariant),
          const SizedBox(height: 8),
          for (final rule in category.rules)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 19,
                    color: category.color,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(rule)),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.tertiaryContainer.withAlpha(130),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              category.warning,
              style: TextStyle(
                color: colors.onTertiaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WasteCategory {
  const _WasteCategory({
    required this.title,
    required this.summary,
    required this.rules,
    required this.warning,
    required this.icon,
    required this.color,
  });

  final String title;
  final String summary;
  final List<String> rules;
  final String warning;
  final IconData icon;
  final Color color;
}

const _categories = [
  _WasteCategory(
    title: 'Plastics',
    summary: 'Check the resin code and keep items clean.',
    rules: [
      'Rinse bottles and containers before recycling.',
      'Keep caps attached when your local facility accepts them.',
      'Take plastic bags and film to dedicated collection points.',
    ],
    warning:
        'Avoid wish-cycling: dirty or mixed plastics can contaminate a full batch.',
    icon: Icons.local_drink_outlined,
    color: Color(0xFF1976D2),
  ),
  _WasteCategory(
    title: 'Glass',
    summary: 'Infinitely recyclable when correctly sorted.',
    rules: [
      'Empty and lightly rinse jars and bottles.',
      'Separate glass by color where local bins require it.',
      'Remove corks and lids if your collection guide asks you to.',
    ],
    warning:
        'Do not mix mirrors, ceramics, or drinking glasses with container glass.',
    icon: Icons.wine_bar_outlined,
    color: Color(0xFF00897B),
  ),
  _WasteCategory(
    title: 'Electronics',
    summary: 'Recover valuable metals and protect data.',
    rules: [
      'Back up and securely erase personal data.',
      'Remove batteries when the device allows it.',
      'Use municipal e-waste events or authorized retailers.',
    ],
    warning:
        'Never place phones, batteries, or laptops in household recycling bins.',
    icon: Icons.devices_other_outlined,
    color: Color(0xFF6A1B9A),
  ),
  _WasteCategory(
    title: 'Organics',
    summary: 'Turn food scraps into soil instead of methane.',
    rules: [
      'Compost fruit, vegetables, coffee grounds, and eggshells.',
      'Keep plastic packaging and produce stickers out.',
      'Balance wet food scraps with dry leaves or cardboard.',
    ],
    warning:
        'Meat and dairy belong only in systems that explicitly accept them.',
    icon: Icons.compost_outlined,
    color: Color(0xFF558B2F),
  ),
  _WasteCategory(
    title: 'Oils',
    summary: 'Store used oil safely for specialist collection.',
    rules: [
      'Cool cooking oil and pour it into a sealed container.',
      'Take motor oil to an authorized service or collection site.',
      'Keep different oil types separate and clearly labeled.',
    ],
    warning:
        'Never pour oil down the drain. It blocks pipes and pollutes waterways.',
    icon: Icons.oil_barrel_outlined,
    color: Color(0xFFEF6C00),
  ),
];
