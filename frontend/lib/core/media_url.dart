class MediaUrl {
  const MediaUrl._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ecovision-backend-wdr0.onrender.com',
  );

  static String? resolve(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;

    final base = _configuredBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    if (!uri.hasScheme) {
      return '$base/${raw.replaceFirst(RegExp(r'^/+'), '')}';
    }

    final localHost =
        uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    if (localHost && uri.path.startsWith('/uploads/')) {
      return '$base${uri.path}';
    }
    return raw;
  }
}
