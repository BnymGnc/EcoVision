import 'package:flutter/material.dart';

import 'stub_screen_scaffold.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StubScreenScaffold(
      title: 'Liderlik Tablosu',
      icon: Icons.emoji_events_outlined,
      heading: 'City rankings are coming soon',
      message: 'Compete with local recyclers and celebrate collective impact.',
    );
  }
}
