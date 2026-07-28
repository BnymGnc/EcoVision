import 'package:ecovision/services/api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'HTML sunucu hatasını kullanıcı dostu API hatasına dönüştürür',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          '<html><body>Bad Gateway</body></html>',
          502,
          headers: {'content-type': 'text/html'},
        ),
      );
      final service = ApiService(client: client);

      await expectLater(
        service.login(email: 'user@ecovision.test', password: 'Test123!'),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            'Sunucuya şu an ulaşılamıyor, lütfen tekrar deneyin.',
          ),
        ),
      );
    },
  );
}
