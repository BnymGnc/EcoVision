class AcademyModule {
  const AcademyModule({
    required this.categoryId,
    required this.title,
    required this.contentBody,
    required this.questions,
  });

  final String categoryId;
  final String title;
  final String contentBody;
  final List<AcademyQuestion> questions;

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
      questions: List.unmodifiable(
        rawQuestions.map(
          (question) => AcademyQuestion.fromJson(
            Map<String, dynamic>.from(question as Map),
          ),
        ),
      ),
    );
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
