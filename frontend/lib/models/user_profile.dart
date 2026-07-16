class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.totalPoints,
    required this.role,
    this.age,
    this.profilePictureUrl,
  });

  final int id;
  final String name;
  final String surname;
  final String email;
  final int totalPoints;
  final String role;
  final int? age;
  final String? profilePictureUrl;

  String get fullName => '$name $surname'.trim();
  bool get isAdmin => role == 'ADMIN' || role == 'SUPERUSER';
  bool get isSuperuser => role == 'SUPERUSER';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      surname: (json['surname'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      age: json['age'] == null ? null : (json['age'] as num).toInt(),
      profilePictureUrl: json['profilePictureUrl']?.toString(),
      totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
      role: (json['role'] ?? 'USER').toString(),
    );
  }
}
