import 'package:share_plus/share_plus.dart';

class EcoShareService {
  const EcoShareService._();

  static const upgradeText =
      'EcoVision\'da Eko Avatarımı geliştirdim! Gezegenimizi korumak için sen de bana katıl. 🌍♻️';

  static Future<void> shareEcoUpgrade() async {
    await SharePlus.instance.share(
      ShareParams(text: upgradeText, subject: 'EcoVision ilerlemem'),
    );
  }
}
