String loginDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime? _calendarDate(Object? value) {
  final text = value?.toString() ?? '';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
  final parsed = DateTime.tryParse('${text}T00:00:00Z');
  return parsed != null && loginDateKey(parsed) == text ? parsed : null;
}

Set<String> _recordedDates(Object? value) => value is List
    ? value.map(_calendarDate).whereType<DateTime>().map(loginDateKey).toSet()
    : <String>{};

int _count(Object? value) {
  if (value is num && !value.isFinite) return 0;
  final number = value is num ? value.toInt() : int.tryParse('$value');
  return number == null || number < 0 ? 0 : number;
}

class LoginStreakSummary {
  const LoginStreakSummary({
    required this.today,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastSevenDays,
  });
  final DateTime today;
  final int currentStreak;
  final int longestStreak;
  final Set<String> lastSevenDays;

  static LoginStreakSummary? tryParse(Map<String, dynamic>? json) {
    if (json == null || !json.containsKey('currentStreak')) return null;
    final today = _calendarDate(json['today']);
    if (today == null) return null;
    return LoginStreakSummary(
      today: today,
      currentStreak: _count(json['currentStreak']),
      longestStreak: _count(json['longestStreak']),
      lastSevenDays: _recordedDates(json['lastSevenDays']),
    );
  }
}

class LoginActivityMonth {
  const LoginActivityMonth({
    required this.month,
    required this.today,
    required this.loginDates,
    this.partial = false,
  });
  final DateTime month;
  final DateTime today;
  final Set<String> loginDates;
  final bool partial;

  factory LoginActivityMonth.fromJson(Map<String, dynamic> json) {
    final month = _calendarDate('${json['month']}-01');
    final today = _calendarDate(json['today']);
    if (month == null || today == null || json['loginDates'] is! List) {
      throw const FormatException('Giriş takvimi bilgisi geçersiz.');
    }
    return LoginActivityMonth(
      month: month,
      today: today,
      loginDates: _recordedDates(json['loginDates'])
          .where(
            (day) =>
                day.startsWith(loginDateKey(month).substring(0, 7)) &&
                day.compareTo(loginDateKey(today)) <= 0,
          )
          .toSet(),
    );
  }
}
