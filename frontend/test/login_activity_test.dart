import 'package:ecovision/models/login_activity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('eksik veya bozuk seri tarihi çökme üretmez', () {
    expect(LoginStreakSummary.tryParse({}), isNull);
    expect(
      LoginStreakSummary.tryParse({'today': 'bozuk', 'currentStreak': 3}),
      isNull,
    );
    expect(
      LoginStreakSummary.tryParse({'today': '2026-02-30', 'currentStreak': 3}),
      isNull,
    );
  });
  test('takvim yalnız seçilen aydaki gerçek, geçmiş kayıtları tutar', () {
    final month = LoginActivityMonth.fromJson({
      'month': '2024-02',
      'today': '2024-02-29',
      'loginDates': [
        '2024-01-31',
        '2024-02-28',
        '2024-02-29',
        '2024-02-30',
        '2024-03-01',
      ],
    });
    expect(month.month, DateTime.utc(2024, 2, 1));
    expect(month.loginDates, {'2024-02-28', '2024-02-29'});
    expect(loginDateKey(month.today), '2024-02-29');
  });
  test('günler cihaz saat diliminden bağımsız takvim tarihi olarak okunur', () {
    final summary = LoginStreakSummary.tryParse({
      'today': '2026-10-24',
      'currentStreak': 3,
      'longestStreak': 9,
      'lastSevenDays': ['2026-10-24'],
    })!;
    expect(summary.today.isUtc, isTrue);
    expect(summary.currentStreak, 3);
    expect(summary.longestStreak, 9);
    expect(summary.lastSevenDays, {'2026-10-24'});
  });
}
