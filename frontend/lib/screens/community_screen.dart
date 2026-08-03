import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/turkey_locations.dart';
import '../models/community_group.dart';
import '../models/social_models.dart';
import '../services/api_service.dart';
import 'create_community_group_sheet.dart';
import 'group_chat_screen.dart';
import 'public_profile_screen.dart';
import '../widgets/notification_bell.dart';
import '../widgets/premium_ui.dart';
import '../widgets/privacy_aware_avatar.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({
    required this.apiService,
    this.notificationCount = 0,
    this.onNotifications,
    super.key,
  });
  final ApiService apiService;
  final int notificationCount;
  final VoidCallback? onNotifications;
  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  final _userSearch = TextEditingController();
  Timer? _debounce;
  late Future<List<CommunityGroup>> _groups;
  late Future<List<SocialUser>> _friends;
  late Future<List<FriendRequest>> _requests;
  late Future<List<GroupInviteModel>> _invites;
  List<UserDiscovery> _discoveredUsers = const [];
  bool _searchingUser = false;
  final Set<String> _selectedCities = {};
  String _selectedDistrict = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _reload();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _userSearch.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _reload() => setState(() {
    _groups = widget.apiService.fetchCommunityGroups(
      query: _search.text,
      cities: _selectedCities,
      district: _selectedCities.length == 1 ? _selectedDistrict : null,
    );
    _friends = widget.apiService.fetchFriends();
    _requests = widget.apiService.fetchFriendRequests();
    _invites = widget.apiService.fetchGroupInvites();
  });

  void _onSearch(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _onUserSearch(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _discoveredUsers = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), _searchUser);
  }

  Future<void> _selectCities() async {
    var draft = Set<String>.from(_selectedCities);
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .76,
            child: Column(
              children: [
                ListTile(
                  title: const Text(
                    'Şehir filtresi',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(
                    draft.isEmpty
                        ? 'Tüm Şehirler'
                        : '${draft.length} şehir seçildi',
                  ),
                  trailing: TextButton(
                    onPressed: () => setSheetState(draft.clear),
                    child: const Text('Tüm Şehirler'),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: TurkishLocations.provinceNames.length,
                    itemBuilder: (context, index) {
                      final city = TurkishLocations.provinceNames[index];
                      return CheckboxListTile(
                        value: draft.contains(city),
                        title: Text(city),
                        onChanged: (checked) => setSheetState(() {
                          checked == true
                              ? draft.add(city)
                              : draft.remove(city);
                        }),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, draft),
                      child: const Text('Filtreyi Uygula'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _selectedCities
        ..clear()
        ..addAll(selected);
      _selectedDistrict = '';
    });
    _reload();
  }

  Future<void> _join(CommunityGroup group) async {
    await EcoHaptics.light();
    if (group.privateGroup && !group.isJoined) {
      final password = await _askGroupPassword(group);
      if (password == null || !mounted) return;
      await _joinAndOpen(group, password: password);
      return;
    }
    await _joinAndOpen(group);
  }

  Future<String?> _askGroupPassword(CommunityGroup group) async {
    final controller = TextEditingController();
    var obscure = true;
    final password = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Şifreli Grup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${group.name} grubunun şifresini gir.'),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (value) => Navigator.pop(context, value.trim()),
                decoration: InputDecoration(
                  labelText: 'Grup şifresi',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Şifreyi göster' : 'Şifreyi gizle',
                    onPressed: () => setDialogState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Katıl'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (password == null || password.isEmpty) return null;
    return password;
  }

  Future<void> _joinAndOpen(CommunityGroup group, {String? password}) async {
    try {
      final joined = group.isJoined
          ? group
          : await widget.apiService.joinCommunityGroup(
              group.id,
              joinCode: password,
            );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<bool>(
          builder: (_) =>
              GroupChatScreen(apiService: widget.apiService, group: joined),
        ),
      );
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _openInviteCode() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grup Davet Kodu'),
        content: TextField(
          controller: controller,
          autocorrect: false,
          decoration: const InputDecoration(
            hintText: 'Davet kodunu yapıştır',
            prefixIcon: Icon(Icons.link_rounded),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Gruba Git'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    try {
      final group = await widget.apiService.joinCommunityGroupByInvite(code);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) =>
              GroupChatScreen(apiService: widget.apiService, group: group),
        ),
      );
      _reload();
    } catch (error) {
      _showError(error);
    }
  }

  Future<void> _searchUser() async {
    final query = _userSearch.text.trim();
    if (query.length < 3) {
      _showError('Arama için en az 3 karakter yazmalısın.');
      return;
    }
    await EcoHaptics.light();
    setState(() {
      _searchingUser = true;
    });
    try {
      final users = await widget.apiService.searchUsers(query);
      if (mounted) setState(() => _discoveredUsers = users);
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _searchingUser = false);
    }
  }

  Future<void> _sendFriendRequest(UserDiscovery user) async {
    if (user.friendshipStatus == 'PENDING' ||
        user.friendshipStatus == 'ACCEPTED') {
      return;
    }
    await EcoHaptics.light();
    try {
      await widget.apiService.sendFriendRequest(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('@${user.username} için arkadaşlık isteği gönderildi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _searchUser();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _openProfile(int userId) async {
    if (userId <= 0) return;
    await EcoHaptics.light();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            PublicProfileScreen(apiService: widget.apiService, userId: userId),
      ),
    );
    if (mounted) _reload();
  }

  void _showError(Object error) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  @override
  Widget build(BuildContext context) {
    if (!(widget.apiService.currentUser?.adult ?? false)) {
      return const _CommunityAgeLock();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Topluluk'),
        actions: [
          IconButton(
            tooltip: 'Davet koduyla katıl',
            onPressed: _openInviteCode,
            icon: const Icon(Icons.link_rounded),
          ),
          if (widget.onNotifications != null)
            NotificationBell(
              count: widget.notificationCount,
              onPressed: widget.onNotifications!,
            ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(icon: Icon(Icons.groups_outlined), text: 'Gruplar'),
            Tab(icon: Icon(Icons.people_outline), text: 'Arkadaşlar'),
            Tab(icon: Icon(Icons.mail_outline), text: 'Davetler'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          EcoHaptics.light();
          _openCreateGroup();
        },
        icon: const Icon(Icons.group_add_outlined),
        label: const Text('Grup Oluştur'),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_groupsTab(), _friendsTab(), _invitesTab()],
      ),
    );
  }

  Widget _groupsTab() => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          controller: _search,
          onChanged: _onSearch,
          decoration: const InputDecoration(
            hintText: 'Şehrindeki grupları ara',
            prefixIcon: Icon(Icons.search),
            suffixIcon: Icon(Icons.location_city_outlined),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _selectCities,
          icon: const Icon(Icons.location_city_outlined),
          label: Text(
            _selectedCities.isEmpty
                ? 'Tüm Şehirler'
                : _selectedCities.length == 1
                ? _selectedCities.first
                : '${_selectedCities.length} şehir seçildi',
          ),
        ),
        if (_selectedCities.length == 1) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedCities.first),
            initialValue: _selectedDistrict.isEmpty ? null : _selectedDistrict,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'İlçe (isteğe bağlı)',
              prefixIcon: Icon(Icons.holiday_village_outlined),
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('Tüm İlçeler')),
              ...TurkishLocations.districtsFor(_selectedCities.first).map(
                (district) =>
                    DropdownMenuItem(value: district, child: Text(district)),
              ),
            ],
            onChanged: (district) {
              setState(() => _selectedDistrict = district ?? '');
              _reload();
            },
          ),
        ],
        const SizedBox(height: 14),
        FutureBuilder<List<CommunityGroup>>(
          future: _groups,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const _Loading();
            if (snapshot.hasError)
              return _Empty(
                icon: Icons.cloud_off_outlined,
                title: 'Gruplar yüklenemedi',
                message: snapshot.error.toString(),
                action: _reload,
              );
            final groups = snapshot.data ?? const [];
            if (groups.isEmpty)
              return _Empty(
                icon: Icons.groups_outlined,
                title: 'Şehrinde grup bulunamadı',
                message:
                    'Aramana uygun bir grup yok. İlk grubu sen kurabilirsin.',
                action: _openCreateGroup,
              );
            return Column(
              children: groups
                  .map(
                    (group) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _GroupCard(
                        group: group,
                        onTap: () => _join(group),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  Widget _friendsTab() => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        TextField(
          controller: _userSearch,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          onChanged: _onUserSearch,
          onSubmitted: (_) => _searchUser(),
          decoration: InputDecoration(
            hintText: 'Ad veya kullanıcı adı ara',
            helperText: 'En az 3 karakter yaz',
            prefixIcon: const Icon(Icons.person_search_outlined),
            suffixIcon: IconButton(
              tooltip: 'Kullanıcıyı ara',
              onPressed: _searchingUser ? null : _searchUser,
              icon: const Icon(Icons.search_rounded),
            ),
          ),
        ),
        if (_searchingUser) ...[
          const SizedBox(height: 12),
          const EcoShimmerList(itemCount: 1, padding: EdgeInsets.zero),
        ],
        if (!_searchingUser &&
            _discoveredUsers.isEmpty &&
            _userSearch.text.trim().length >= 3) ...[
          const SizedBox(height: 12),
          const Text('Aramana uygun kullanıcı bulunamadı.'),
        ],
        if (_discoveredUsers.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._discoveredUsers.map(
            (user) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _DiscoveryCard(
                user: user,
                onTap: () => _openProfile(user.id),
                onFriendRequest: () => _sendFriendRequest(user),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        const _SectionTitle('Arkadaşlık İstekleri'),
        FutureBuilder<List<FriendRequest>>(
          future: _requests,
          builder: (context, snapshot) {
            final requests = snapshot.data ?? const [];
            if (snapshot.connectionState == ConnectionState.waiting)
              return const EcoShimmerList(
                itemCount: 2,
                padding: EdgeInsets.zero,
              );
            if (requests.isEmpty)
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text('Bekleyen arkadaşlık isteğin yok.'),
              );
            return Column(
              children: requests
                  .map(
                    (request) => ListTile(
                      leading: _Avatar(user: request.requester),
                      title: Text(request.requester.fullName),
                      subtitle: Text(request.requester.city),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          IconButton(
                            tooltip: 'Reddet',
                            onPressed: () async {
                              await EcoHaptics.light();
                              try {
                                await widget.apiService.rejectFriendRequest(
                                  request.id,
                                );
                                _reload();
                              } catch (e) {
                                _showError(e);
                              }
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                          IconButton.filled(
                            tooltip: 'Kabul Et',
                            onPressed: () async {
                              await EcoHaptics.light();
                              try {
                                await widget.apiService.acceptFriendRequest(
                                  request.id,
                                );
                                _reload();
                              } catch (e) {
                                _showError(e);
                              }
                            },
                            icon: const Icon(Icons.check_rounded),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
        const Divider(height: 32),
        const _SectionTitle('Arkadaşlarım'),
        FutureBuilder<List<SocialUser>>(
          future: _friends,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting)
              return const _Loading();
            final friends = snapshot.data ?? const [];
            if (friends.isEmpty)
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'Henüz arkadaşın yok. Liderlik tablosundan yeni kahramanlar keşfet.',
                ),
              );
            return Column(
              children: friends
                  .map(
                    (friend) => ListTile(
                      onTap: () => _openProfile(friend.id),
                      leading: _Avatar(user: friend),
                      title: Text(friend.fullName),
                      subtitle: Text(
                        '${friend.city} • Avatar ${friend.avatarLevel}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    ),
  );

  Widget _invitesTab() => RefreshIndicator(
    onRefresh: () async => _reload(),
    child: FutureBuilder<List<GroupInviteModel>>(
      future: _invites,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: const [_Loading()],
          );
        }
        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              _Empty(
                icon: Icons.error_outline,
                title: 'Davetler yüklenemedi',
                message: snapshot.error.toString(),
                action: _reload,
              ),
            ],
          );
        }
        final invites = snapshot.data ?? const [];
        if (invites.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: const [
              _Empty(
                icon: Icons.mark_email_read_outlined,
                title: 'Yeni davet yok',
                message: 'Özel grup davetlerin burada görünecek.',
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: invites
              .map(
                (invite) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invite.eventTitle,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text('${invite.inviter.fullName} seni davet etti'),
                        Text(invite.location),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () async {
                            try {
                              await widget.apiService.acceptGroupInvite(
                                invite.id,
                              );
                              _reload();
                            } catch (e) {
                              _showError(e);
                            }
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Daveti Kabul Et'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );

  void _openCreateGroup() => showEcoGlassSheet<void>(
    context: context,
    builder: (_) => CreateCommunityGroupSheet(
      apiService: widget.apiService,
      onCreated: _reload,
    ),
  );
}

class _CommunityAgeLock extends StatelessWidget {
  const _CommunityAgeLock();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Topluluk')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_person_outlined,
                  size: 52,
                  color: colors.onErrorContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '18+ erişim alanı',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Topluluk, grup ve sohbet özellikleri yalnızca 18 yaşını '
                'doldurmuş EcoVision kullanıcılarına açıktır.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.apiService, required this.onCreated});
  final ApiService apiService;
  final VoidCallback onCreated;
  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _code = TextEditingController();
  final _neighborhood = TextEditingController();
  final _exactAddress = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _city;
  String? _district;
  DateTime _date = DateTime.now().add(const Duration(days: 2));
  int _limit = 20;
  bool _saving = false;
  Uint8List? _coverBytes;
  String? _coverFileName;
  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _code.dispose();
    _neighborhood.dispose();
    _exactAddress.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kapak fotoğrafı 5 MB altında olmalı.')),
        );
      }
      return;
    }
    if (mounted) {
      setState(() {
        _coverBytes = bytes;
        _coverFileName = image.name;
      });
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _date,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null)
      setState(
        () => _date = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.apiService.createCleanupEvent(
        title: _title.text.trim(),
        description: _description.text.trim(),
        city: _city!,
        district: _district!,
        neighborhood: _neighborhood.text.trim(),
        eventDate: _date,
        exactAddress: _exactAddress.text.trim(),
        memberLimit: _limit,
        joinCode: _code.text.trim(),
        coverBytes: _coverBytes,
        coverFileName: _coverFileName,
      );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const EcoSheetHandle(),
            Text(
              'Yeni Temizlik Etkinliği',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _saving ? null : _pickCover,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 150,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _coverBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, size: 38),
                          SizedBox(height: 8),
                          Text('Etkinlik kapak fotoğrafı ekle'),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_coverBytes!, fit: BoxFit.cover),
                          const Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: CircleAvatar(
                                child: Icon(Icons.edit_outlined),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Etkinlik başlığı',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Etkinlik başlığı gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Amaç ve açıklama'),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Açıklama gerekli' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _city,
              decoration: const InputDecoration(
                labelText: 'İl',
                hintText: 'İl seçin',
              ),
              items: TurkishLocations.provinceNames
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() {
                _city = v;
                _district = null;
              }),
              validator: (value) =>
                  value == null ? 'Lütfen bir il seçin' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _district,
              key: ValueKey('d$_city'),
              decoration: const InputDecoration(
                labelText: 'İlçe',
                hintText: 'Önce il, sonra ilçe seçin',
              ),
              items: _city == null
                  ? const <DropdownMenuItem<String>>[]
                  : TurkishLocations.districtsFor(_city!)
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
              onChanged: _city == null
                  ? null
                  : (v) => setState(() => _district = v),
              validator: (value) =>
                  value == null ? 'Lütfen bir ilçe seçin' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _neighborhood,
              decoration: const InputDecoration(
                labelText: 'Mahalle',
                prefixIcon: Icon(Icons.holiday_village_outlined),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Mahalle gerekli' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _exactAddress,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Açık adres / buluşma noktası',
                prefixIcon: Icon(Icons.pin_drop_outlined),
              ),
              validator: (value) => (value ?? '').trim().length < 8
                  ? 'Açık adres en az 8 karakter olmalı'
                  : null,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Buluşma zamanı'),
              subtitle: Text(
                '${_date.day}.${_date.month}.${_date.year} ${_date.hour.toString().padLeft(2, '0')}:${_date.minute.toString().padLeft(2, '0')}',
              ),
              trailing: TextButton(
                onPressed: _pickDate,
                child: const Text('Değiştir'),
              ),
            ),
            Row(
              children: [
                const Expanded(child: Text('Üye sınırı')),
                DropdownButton<int>(
                  value: _limit,
                  items: [10, 20, 50, 100]
                      .map(
                        (v) =>
                            DropdownMenuItem(value: v, child: Text('$v kişi')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _limit = v!),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _code,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Katılım parolası (isteğe bağlı)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add),
                label: const Text('Etkinliği Oluştur'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group, required this.onTap});
  final CommunityGroup group;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: group.coverImageUrl == null
                      ? null
                      : NetworkImage(group.coverImageUrl!),
                  child: group.coverImageUrl == null
                      ? Icon(
                          group.privateGroup
                              ? Icons.lock_outline
                              : Icons.eco_outlined,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(group.locationLabel),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              group.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                Chip(
                  label: Text('${group.memberCount}/${group.memberLimit} üye'),
                ),
                if (group.isJoined)
                  const Chip(
                    avatar: Icon(Icons.check_circle, size: 17),
                    label: Text('Üyesin'),
                  ),
                if (!group.isJoined && group.privateGroup)
                  const Chip(
                    avatar: Icon(Icons.lock_outline_rounded, size: 17),
                    label: Text('Şifreli'),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final SocialUser user;
  @override
  Widget build(BuildContext context) => PrivacyAwareAvatar(
    userId: user.id,
    currentUserId: null,
    avatarLevel: user.avatarLevel,
    highestAvatarLevel: user.highestAvatarLevel,
    profileImagePreference: user.profileImagePreference,
    adult: user.adult,
    profileVisibility: user.profileVisibility,
    profilePictureUrl: user.profilePictureUrl,
    selectedAvatarPath: user.selectedAvatarPath,
    friendshipStatus: user.friendshipStatus,
  );
}

class _DiscoveryCard extends StatelessWidget {
  const _DiscoveryCard({
    required this.user,
    required this.onTap,
    required this.onFriendRequest,
  });
  final UserDiscovery user;
  final VoidCallback onTap;
  final VoidCallback onFriendRequest;

  @override
  Widget build(BuildContext context) => GlassPanel(
    tint: Theme.of(context).colorScheme.primaryContainer,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: PrivacyAwareAvatar(
        userId: user.id,
        currentUserId: null,
        avatarLevel: user.avatarLevel,
        highestAvatarLevel: user.highestAvatarLevel,
        profileImagePreference: user.profileImagePreference,
        adult: user.adult,
        profileVisibility: user.profileVisibility,
        profilePictureUrl: user.profilePictureUrl,
        selectedAvatarPath: user.selectedAvatarPath,
        friendshipStatus: user.friendshipStatus,
      ),
      title: Text(
        user.fullName,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text('@${user.username} • ${user.city}'),
      trailing: IconButton(
        tooltip: user.friendshipStatus == 'ACCEPTED'
            ? 'Arkadaşsınız'
            : user.friendshipStatus == 'PENDING'
            ? 'İstek bekliyor'
            : 'Arkadaş ekle',
        onPressed:
            user.friendshipStatus == 'ACCEPTED' ||
                user.friendshipStatus == 'PENDING'
            ? null
            : onFriendRequest,
        icon: Icon(
          user.friendshipStatus == 'ACCEPTED'
              ? Icons.people_alt_rounded
              : user.friendshipStatus == 'PENDING'
              ? Icons.hourglass_top_rounded
              : Icons.person_add_alt_1_rounded,
        ),
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const EcoShimmerList(itemCount: 4, padding: EdgeInsets.zero);
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final VoidCallback? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 108,
          height: 108,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 58,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonalIcon(
            onPressed: action,
            icon: const Icon(Icons.refresh),
            label: const Text('Yenile'),
          ),
        ],
      ],
    ),
  );
}
