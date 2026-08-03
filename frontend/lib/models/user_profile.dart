import '../core/media_url.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.totalPoints,
    required this.role,
    required this.city,
    required this.ownedMarketItems,
    this.username = '',
    this.profileVisibility = 'PUBLIC',
    this.profileImagePreference = 'AVATAR',
    this.themePreference = 'forest',
    this.district = '',
    this.neighborhood = '',
    this.selectedAvatarPath = 'assets/images/avatars/avatar_level_1.png',
    this.equippedAvatarLevel = 1,
    this.currentAvatarLevel = 1,
    this.lifetimePoints = 0,
    this.age,
    this.profilePictureUrl,
    this.adult = false,
    this.streakCount = 0,
    this.streakFreezeCount = 0,
    this.lastScanDate,
    this.banned = false,
    this.suspendedUntil,
  });

  final int id;
  final String name;
  final String username;
  final String surname;
  final String email;
  final int totalPoints;
  final String role;
  final String profileVisibility;
  final String profileImagePreference;
  final String themePreference;
  final String city;
  final String district;
  final String neighborhood;
  final Set<String> ownedMarketItems;
  final String selectedAvatarPath;
  final int equippedAvatarLevel;
  final int currentAvatarLevel;
  final int lifetimePoints;
  final int? age;
  final String? profilePictureUrl;
  final bool adult;
  final int streakCount;
  final int streakFreezeCount;
  final DateTime? lastScanDate;
  final bool banned;
  final DateTime? suspendedUntil;

  String get fullName => '$name $surname'.trim();
  bool get isAdmin => role == 'ADMIN' || role == 'SUPERUSER';
  bool get isSuperuser => role == 'SUPERUSER';

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num).toInt(),
      username: (json['username'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      surname: (json['surname'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      age: json['age'] == null ? null : (json['age'] as num).toInt(),
      profilePictureUrl: MediaUrl.resolve(json['profilePictureUrl']),
      totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
      role: (json['role'] ?? 'USER').toString(),
      profileVisibility: (json['profileVisibility'] ?? 'PUBLIC').toString(),
      profileImagePreference:
          (json['profileImagePreference'] ??
                  (json['profilePictureUrl'] == null
                      ? 'AVATAR'
                      : 'CUSTOM_PHOTO'))
              .toString(),
      themePreference: (json['themePreference'] ?? 'forest').toString(),
      city: (json['city'] ?? '').toString(),
      district: (json['district'] ?? '').toString(),
      neighborhood: (json['neighborhood'] ?? '').toString(),
      ownedMarketItems: json['ownedMarketItems'] is List
          ? (json['ownedMarketItems'] as List)
                .map((item) => item.toString())
                .toSet()
          : <String>{},
      selectedAvatarPath:
          (json['selectedAvatarPath'] ??
                  'assets/images/avatars/avatar_level_1.png')
              .toString(),
      equippedAvatarLevel: (json['equippedAvatarLevel'] as num? ?? 1).toInt(),
      currentAvatarLevel:
          (json['currentAvatarLevel'] as num? ??
                  json['equippedAvatarLevel'] as num? ??
                  1)
              .toInt(),
      lifetimePoints:
          (json['lifetimePoints'] as num? ?? json['totalPoints'] as num? ?? 0)
              .toInt(),
      adult: json['adult'] as bool? ?? ((json['age'] as num? ?? 0) >= 18),
      streakCount: (json['streakCount'] as num? ?? 0).toInt(),
      streakFreezeCount: (json['streakFreezeCount'] as num? ?? 0).toInt(),
      lastScanDate: DateTime.tryParse((json['lastScanDate'] ?? '').toString()),
      banned: json['banned'] as bool? ?? false,
      suspendedUntil: DateTime.tryParse(
        (json['suspendedUntil'] ?? '').toString(),
      ),
    );
  }
}
