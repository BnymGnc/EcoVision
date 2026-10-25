import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'media_session.dart';

Future<void> downloadAuthorizedMedia(
  BuildContext context,
  String url,
  String fileName,
) async {
  try {
    final bytes = await MediaSession.load(Uri.parse(url));
    final safeName = fileName.replaceAll(RegExp(r'[\\/\r\n]'), '_');
    await FilePicker.platform.saveFile(
      dialogTitle: 'Belgeyi kaydet',
      fileName: safeName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belge indirilemedi veya erişim iznin yok.'),
        ),
      );
    }
  }
}
