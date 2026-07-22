import 'package:flutter/material.dart';

import 'stub_screen_scaffold.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StubScreenScaffold(
      title: 'Edit Profile',
      icon: Icons.manage_accounts_outlined,
      heading: 'Profile editor is coming soon',
      message: 'Soon you will be able to update your personal details here.',
    );
  }
}
