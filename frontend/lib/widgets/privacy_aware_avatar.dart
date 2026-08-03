import 'package:flutter/material.dart';

abstract final class ProfilePhotoPolicy {
  static bool canShowCustomPhoto({
    required int userId,
    required int? currentUserId,
    required bool adult,
    required String profileVisibility,
    required String? profilePictureUrl,
    String? profileImagePreference,
    String? friendshipStatus,
  }) {
    final picture = profilePictureUrl?.trim();
    if (!adult || picture == null || picture.isEmpty) return false;
    final preference = profileImagePreference?.trim().toUpperCase();
    if (preference != null &&
        preference.isNotEmpty &&
        preference != 'CUSTOM_PHOTO') {
      return false;
    }
    return currentUserId == userId ||
        profileVisibility.toUpperCase() == 'PUBLIC' ||
        friendshipStatus?.toUpperCase() == 'ACCEPTED';
  }
}

/// Applies the same age and profile-visibility policy everywhere a user image
/// is rendered. Custom photos are never shown for minors.
class PrivacyAwareAvatar extends StatelessWidget {
  const PrivacyAwareAvatar({
    required this.userId,
    required this.currentUserId,
    required this.avatarLevel,
    required this.adult,
    required this.profileVisibility,
    this.profileImagePreference,
    this.highestAvatarLevel,
    this.profilePictureUrl,
    this.selectedAvatarPath,
    this.friendshipStatus,
    this.radius = 20,
    this.backgroundColor,
    this.borderColor,
    super.key,
  });

  final int userId;
  final int? currentUserId;
  final int avatarLevel;
  final bool adult;
  final String profileVisibility;
  final String? profileImagePreference;
  final int? highestAvatarLevel;
  final String? profilePictureUrl;
  final String? selectedAvatarPath;
  final String? friendshipStatus;
  final double radius;
  final Color? backgroundColor;
  final Color? borderColor;

  bool get _canShowCustomPhoto => ProfilePhotoPolicy.canShowCustomPhoto(
    userId: userId,
    currentUserId: currentUserId,
    adult: adult,
    profileVisibility: profileVisibility,
    profilePictureUrl: profilePictureUrl,
    profileImagePreference: profileImagePreference,
    friendshipStatus: friendshipStatus,
  );

  String get _avatarAsset {
    final preference = profileImagePreference?.trim().toUpperCase();
    final hiddenFromViewer =
        currentUserId != userId &&
        profileVisibility.toUpperCase() == 'FRIENDS_ONLY' &&
        friendshipStatus?.toUpperCase() != 'ACCEPTED';
    final usesCustomPhoto =
        preference == 'CUSTOM_PHOTO' ||
        ((preference == null || preference.isEmpty) &&
            profilePictureUrl?.trim().isNotEmpty == true);
    if (hiddenFromViewer || usesCustomPhoto) {
      final safeHighest = (highestAvatarLevel ?? avatarLevel).clamp(1, 20);
      return 'assets/images/avatars/avatar_level_$safeHighest.png';
    }
    final configured = selectedAvatarPath?.trim();
    if (configured != null && configured.isNotEmpty) return configured;
    final safeLevel = avatarLevel.clamp(1, 20);
    return 'assets/images/avatars/avatar_level_$safeLevel.png';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final size = radius * 2;
    final fallback = Image.asset(
      _avatarAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Center(
        child: Icon(
          Icons.eco_rounded,
          size: radius,
          color: colors.onPrimaryContainer,
        ),
      ),
    );

    return Semantics(
      image: true,
      label: _canShowCustomPhoto ? 'Profil fotoğrafı' : 'EcoVision avatarı',
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(radius >= 40 ? 4 : 2),
        decoration: BoxDecoration(
          color: backgroundColor ?? colors.primaryContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? colors.outlineVariant,
            width: radius >= 40 ? 3 : 1.5,
          ),
        ),
        child: ClipOval(
          child: _canShowCustomPhoto
              ? Image.network(
                  profilePictureUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                )
              : fallback,
        ),
      ),
    );
  }
}
