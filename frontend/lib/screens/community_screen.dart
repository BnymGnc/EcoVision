import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../models/cleanup_event.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../widgets/eco_lottie.dart';
import 'event_chat_screen.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({required this.apiService, super.key});

  final ApiService apiService;

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  late Future<List<CleanupEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = widget.apiService.fetchEvents();
  }

  Future<void> _refresh() async {
    setState(() {
      _eventsFuture = widget.apiService.fetchEvents();
    });
    await _eventsFuture;
  }

  Future<void> _joinEvent(CleanupEvent event) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const EcoLottie(
                url: AppConstants.celebrationLottieUrl,
                fallbackIcon: Icons.volunteer_activism_outlined,
                size: 150,
                repeat: false,
              ),
              Text(
                'Event joined',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(event.title, textAlign: TextAlign.center),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Open Chat'),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            EventChatScreen(apiService: widget.apiService, event: event),
      ),
    );
  }

  void _openReportSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => _ReportCleanupSheet(
        apiService: widget.apiService,
        onCreated: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Community')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openReportSheet,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Report Waste'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<CleanupEvent>>(
            future: _eventsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    const SizedBox(height: 80),
                    _CommunityStateCard(
                      icon: Icons.cloud_off_outlined,
                      title: 'Community is taking a breather',
                      message:
                          'Events could not be loaded right now. Pull to refresh or try again.',
                      actionLabel: 'Retry',
                      onAction: _refresh,
                    ),
                  ],
                );
              }

              final events = snapshot.requireData;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cleanup hub',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Report large waste areas, organize a cleanup, or coordinate with volunteers.',
                            style: TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _openReportSheet,
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: const Text(
                              'Report Waste & Organize Cleanup',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Upcoming events',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (events.isEmpty)
                    _CommunityStateCard(
                      icon: Icons.event_available_outlined,
                      title: 'No events found',
                      message:
                          'Create the first cleanup event and invite the community.',
                      actionLabel: 'Report Waste',
                      onAction: _openReportSheet,
                    )
                  else
                    for (final event in events)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _EventCard(
                          event: event,
                          onJoin: () => _joinEvent(event),
                          onOpenChat: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => EventChatScreen(
                                apiService: widget.apiService,
                                event: event,
                              ),
                            ),
                          ),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CommunityStateCard extends StatelessWidget {
  const _CommunityStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            EcoLottie(
              url: AppConstants.loadingLottieUrl,
              fallbackIcon: icon,
              size: 132,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(icon),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.onJoin,
    required this.onOpenChat,
  });

  final CleanupEvent event;
  final VoidCallback onJoin;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onOpenChat,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (event.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    event.imageUrl!,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.park_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${event.dateLabel} - ${event.creatorName}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(event.description),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      event.location,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onJoin,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(Icons.group_add_outlined),
                    label: const Text('Join'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCleanupSheet extends StatefulWidget {
  const _ReportCleanupSheet({
    required this.apiService,
    required this.onCreated,
  });

  final ApiService apiService;
  final Future<void> Function() onCreated;

  @override
  State<_ReportCleanupSheet> createState() => _ReportCleanupSheetState();
}

class _ReportCleanupSheetState extends State<_ReportCleanupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final LocationService _locationService = LocationService();

  XFile? _photo;
  DateTime _eventDate = DateTime.now().add(const Duration(days: 2));
  bool _isSaving = false;
  bool _isLocating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final photo = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
    if (photo == null || !mounted) {
      return;
    }
    setState(() => _photo = photo);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: _eventDate,
    );
    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_eventDate),
    );
    if (time == null) {
      return;
    }

    setState(() {
      _eventDate = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      final location = await _locationService.getCurrentOrFallbackLocation();
      if (!mounted) {
        return;
      }
      _locationController.text =
          '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
    } finally {
      if (mounted) {
        setState(() => _isLocating = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.apiService.createCleanupEvent(
        title: _titleController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        eventDate: _eventDate,
        photoPath: _photo?.path,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop();
      await widget.onCreated();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cleanup event created.')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _eventDate.toLocal().toString().split('.').first;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Report Waste & Organize Cleanup',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickPhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                _photo == null ? 'Add Waste Photo' : 'Waste Photo Selected',
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Event title',
                prefixIcon: Icon(Icons.title_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Title is required'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                prefixIcon: Icon(Icons.notes_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Description is required'
                  : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                prefixIcon: Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Location is required'
                  : null,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSaving || _isLocating
                    ? null
                    : _useCurrentLocation,
                icon: _isLocating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: const Text('Use My Current Location'),
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickDateTime,
              icon: const Icon(Icons.event_outlined),
              label: Text(dateLabel),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isSaving ? null : _submit,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('Create Cleanup'),
            ),
          ],
        ),
      ),
    );
  }
}
