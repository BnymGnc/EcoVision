class GroupWasteReport {
  const GroupWasteReport({
    required this.id,
    required this.reporterName,
    required this.materialType,
    required this.itemCount,
    required this.reportedAt,
  });

  final int id;
  final String reporterName;
  final String materialType;
  final int itemCount;
  final DateTime reportedAt;

  factory GroupWasteReport.fromJson(Map<String, dynamic> json) =>
      GroupWasteReport(
        id: (json['id'] as num).toInt(),
        reporterName: (json['reporterName'] ?? '').toString(),
        materialType: (json['materialType'] ?? '').toString(),
        itemCount: (json['itemCount'] as num? ?? 0).toInt(),
        reportedAt:
            DateTime.tryParse((json['reportedAt'] ?? '').toString()) ??
            DateTime.now(),
      );
}
