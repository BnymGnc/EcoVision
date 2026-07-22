class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.createdAt,
  });
  final int id;
  final String title;
  final String message;
  final String type;
  final bool read;
  final DateTime createdAt;
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        title: (json['title'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        type: (json['type'] ?? 'SYSTEM').toString(),
        read: json['read'] as bool? ?? false,
        createdAt:
            DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}
