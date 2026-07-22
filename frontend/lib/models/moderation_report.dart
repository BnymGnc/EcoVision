class ModerationReport {
  const ModerationReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.reportedUserId,
    this.reportedUserName,
    this.groupId,
    this.groupTitle,
    this.details,
  });
  final int id, reporterId;
  final String reporterName, reason, status;
  final DateTime createdAt;
  final int? reportedUserId, groupId;
  final String? reportedUserName, groupTitle, details;
  bool get isGroup => groupId != null;
  factory ModerationReport.fromJson(Map<String, dynamic> json) =>
      ModerationReport(
        id: (json['id'] as num).toInt(),
        reporterId: (json['reporterId'] as num).toInt(),
        reporterName: (json['reporterName'] ?? '').toString(),
        reportedUserId: (json['reportedUserId'] as num?)?.toInt(),
        reportedUserName: json['reportedUserName']?.toString(),
        groupId: (json['groupId'] as num?)?.toInt(),
        groupTitle: json['groupTitle']?.toString(),
        reason: (json['reason'] ?? '').toString(),
        details: json['details']?.toString(),
        status: (json['status'] ?? 'OPEN').toString(),
        createdAt:
            DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}
