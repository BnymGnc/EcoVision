import 'dart:convert';

import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants.dart';
import '../models/scan_result.dart';

class GeminiService {
  GeminiService({GenerativeModel? model})
    : _model =
          model ??
          GenerativeModel(
            model: AppConstants.geminiModel,
            apiKey: AppConstants.geminiApiKey,
          );

  final GenerativeModel _model;

  Future<ScanResult> analyzeWasteImage(XFile image) async {
    final bytes = await image.readAsBytes();
    final mimeType = image.mimeType ?? _inferMimeType(image.path);

    final response = await _model.generateContent([
      Content.multi([
        TextPart(AppConstants.geminiPrompt),
        DataPart(mimeType, bytes),
      ]),
    ]);

    final text = response.text;
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Gemini returned an empty response.');
    }

    final decoded = jsonDecode(_extractJsonObject(text));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Gemini response was not a JSON object.');
    }

    return ScanResult.fromJson(decoded);
  }

  String _extractJsonObject(String rawText) {
    final cleaned = rawText
        .replaceAll(RegExp(r'```json|```', caseSensitive: false), '')
        .trim();
    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');

    if (start == -1 || end == -1 || end <= start) {
      throw const FormatException('Could not find a valid JSON object.');
    }

    return cleaned.substring(start, end + 1);
  }

  String _inferMimeType(String path) {
    final lowerPath = path.toLowerCase();
    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerPath.endsWith('.heic') || lowerPath.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}
