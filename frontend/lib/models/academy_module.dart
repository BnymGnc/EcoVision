class AcademyModule {
  const AcademyModule({
    required this.categoryId,
    required this.title,
    required this.contentBody,
    required this.questions,
    this.summary = '',
    this.collectionRoute = '',
    this.aiTip = '',
    this.safetyNote = '',
    this.preparation = const [],
    this.mistakes = const [],
    this.acceptedExamples = const [],
    this.excludedExamples = const [],
    this.reuseIdeas = const [],
    this.sources = const [],
  });

  final String categoryId;
  final String title;
  final String contentBody;
  final List<AcademyQuestion> questions;
  static const quizVersion = '2026-10-24-v1';
  final String summary;
  final String collectionRoute;
  final String aiTip;
  final String safetyNote;
  final List<String> preparation;
  final List<String> mistakes;
  final List<String> acceptedExamples;
  final List<String> excludedExamples;
  final List<String> reuseIdeas;
  final List<AcademySource> sources;

  int get readingMinutes {
    final text = [
      contentBody,
      aiTip,
      safetyNote,
      ...preparation,
      ...mistakes,
      ...acceptedExamples,
      ...excludedExamples,
      ...reuseIdeas,
    ].join(' ');
    return (text.split(RegExp(r'\s+')).length / 160).ceil().clamp(1, 60);
  }

  bool matches(String query) => normalizeGuideText(
    [
      title,
      summary,
      contentBody,
      collectionRoute,
      ...acceptedExamples,
      ...excludedExamples,
    ].join(' '),
  ).contains(normalizeGuideText(query.trim()));

  factory AcademyModule.fromJson(Map<String, dynamic> json) {
    final categoryId = (json['categoryId'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    final contentBody = (json['contentBody'] ?? '').toString().trim();
    final rawQuestions = json['questions'];
    if (categoryId.isEmpty || title.isEmpty || contentBody.isEmpty) {
      throw const FormatException(
        'Akademi modülünde categoryId, title ve contentBody zorunludur.',
      );
    }
    if (rawQuestions is! List || rawQuestions.length != 3) {
      throw FormatException('$categoryId modülünde tam 3 soru bulunmalıdır.');
    }
    return AcademyModule(
      categoryId: categoryId,
      title: title,
      contentBody: contentBody,
      summary: (json['summary'] ?? '').toString().trim(),
      collectionRoute: (json['collectionRoute'] ?? '').toString().trim(),
      aiTip: (json['aiTip'] ?? '').toString().trim(),
      safetyNote: (json['safetyNote'] ?? '').toString().trim(),
      preparation: _strings(json, 'preparation'),
      mistakes: _strings(json, 'mistakes'),
      acceptedExamples: _strings(json, 'acceptedExamples'),
      excludedExamples: _strings(json, 'excludedExamples'),
      reuseIdeas: _strings(json, 'reuseIdeas'),
      sources: List.unmodifiable(
        (json['sources'] as List? ?? const []).map(
          (source) =>
              AcademySource.fromJson(Map<String, dynamic>.from(source as Map)),
        ),
      ),
      questions: List.unmodifiable(
        rawQuestions.map(
          (question) => AcademyQuestion.fromJson(
            Map<String, dynamic>.from(question as Map),
          ),
        ),
      ),
    );
  }

  static List<String> _strings(Map<String, dynamic> json, String key) {
    final raw = json[key];
    if (raw == null) return const [];
    if (raw is! List ||
        raw.any((item) => item is! String || item.trim().isEmpty)) {
      throw FormatException('Akademi $key alanı metin listesi olmalıdır.');
    }
    return List.unmodifiable(raw.cast<String>().map((item) => item.trim()));
  }
}

String normalizeGuideText(String value) => value
    .replaceAll('İ', 'i')
    .replaceAll('I', 'ı')
    .toLowerCase()
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

class AcademySource {
  const AcademySource({required this.title, required this.url});

  final String title;
  final Uri url;

  factory AcademySource.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] ?? '').toString().trim();
    final url = Uri.tryParse((json['url'] ?? '').toString());
    if (title.isEmpty ||
        url == null ||
        url.scheme != 'https' ||
        url.host.isEmpty ||
        url.userInfo.isNotEmpty) {
      throw const FormatException(
        'Akademi kaynağı geçerli bir HTTPS adresi içermelidir.',
      );
    }
    return AcademySource(title: title, url: url);
  }
}

class AcademyQuestion {
  const AcademyQuestion({
    required this.questionText,
    required this.options,
    required this.correctOptionIndex,
  });

  final String questionText;
  final List<String> options;
  final int correctOptionIndex;

  factory AcademyQuestion.fromJson(Map<String, dynamic> json) {
    final questionText = (json['questionText'] ?? '').toString().trim();
    final rawOptions = json['options'];
    final correctOptionIndex =
        (json['correctOptionIndex'] as num?)?.toInt() ?? -1;
    if (questionText.isEmpty || rawOptions is! List || rawOptions.length < 2) {
      throw const FormatException('Akademi sorusu veya seçenekleri geçersiz.');
    }
    final options = rawOptions
        .map((option) => option.toString().trim())
        .toList(growable: false);
    if (options.any((option) => option.isEmpty) ||
        correctOptionIndex < 0 ||
        correctOptionIndex >= options.length) {
      throw const FormatException(
        'Akademi sorusunun doğru cevap indeksi geçersiz.',
      );
    }
    return AcademyQuestion(
      questionText: questionText,
      options: List.unmodifiable(options),
      correctOptionIndex: correctOptionIndex,
    );
  }
}

class EducationCompletionResult {
  const EducationCompletionResult({
    required this.categoryId,
    required this.newlyCompleted,
    required this.pointsAwarded,
    required this.totalPoints,
    required this.message,
  });

  final String categoryId;
  final bool newlyCompleted;
  final int pointsAwarded;
  final int totalPoints;
  final String message;

  factory EducationCompletionResult.fromJson(Map<String, dynamic> json) {
    return EducationCompletionResult(
      categoryId: (json['categoryId'] ?? '').toString(),
      newlyCompleted: json['newlyCompleted'] as bool? ?? false,
      pointsAwarded: (json['pointsAwarded'] as num? ?? 0).toInt(),
      totalPoints: (json['totalPoints'] as num? ?? 0).toInt(),
      message: (json['message'] ?? '').toString(),
    );
  }
}
