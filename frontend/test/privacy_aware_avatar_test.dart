import 'package:ecovision/widgets/privacy_aware_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const photo = 'https://example.test/profile.jpg';

  test('özel fotoğraf reşit olmayan kullanıcılar için daima gizlenir', () {
    expect(
      ProfilePhotoPolicy.canShowCustomPhoto(
        userId: 2,
        currentUserId: 2,
        adult: false,
        profileVisibility: 'PUBLIC',
        profilePictureUrl: photo,
      ),
      isFalse,
    );
  });

  test('gizli profil fotoğrafı yabancılardan saklanır', () {
    expect(
      ProfilePhotoPolicy.canShowCustomPhoto(
        userId: 2,
        currentUserId: 1,
        adult: true,
        profileVisibility: 'FRIENDS_ONLY',
        profilePictureUrl: photo,
      ),
      isFalse,
    );
  });

  test('gizli profil fotoğrafını kabul edilmiş arkadaş görebilir', () {
    expect(
      ProfilePhotoPolicy.canShowCustomPhoto(
        userId: 2,
        currentUserId: 1,
        adult: true,
        profileVisibility: 'FRIENDS_ONLY',
        profilePictureUrl: photo,
        friendshipStatus: 'ACCEPTED',
      ),
      isTrue,
    );
  });

  test('reşit kullanıcının herkese açık fotoğrafı gösterilir', () {
    expect(
      ProfilePhotoPolicy.canShowCustomPhoto(
        userId: 2,
        currentUserId: 1,
        adult: true,
        profileVisibility: 'PUBLIC',
        profilePictureUrl: photo,
      ),
      isTrue,
    );
  });

  test('aktif görsel avatar ise eski fotoğraf URLsi kullanılmaz', () {
    expect(
      ProfilePhotoPolicy.canShowCustomPhoto(
        userId: 2,
        currentUserId: 2,
        adult: true,
        profileVisibility: 'PUBLIC',
        profilePictureUrl: photo,
        profileImagePreference: 'AVATAR',
      ),
      isFalse,
    );
  });
}
