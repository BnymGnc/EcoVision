import 'dart:async';
import 'dart:convert';

import 'package:ecovision/core/turkey_locations.dart';
import 'package:ecovision/models/community_group.dart';
import 'package:ecovision/models/social_models.dart';
import 'package:ecovision/models/user_profile.dart';
import 'package:ecovision/screens/community_screen.dart';
import 'package:ecovision/screens/create_community_group_sheet.dart';
import 'package:ecovision/screens/register_screen.dart';
import 'package:ecovision/screens/edit_profile_screen.dart';
import 'package:ecovision/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('81 il, 973 gerçek ilçe ve asset/Dart katalogları eşleşir', () async {
    final source = jsonDecode(
      await rootBundle.loadString('assets/data/turkey_locations.json'),
    );
    expect(TurkishLocations.provinces.length, 81);
    expect(
      TurkishLocations.provinces.values.fold<int>(0, (n, a) => n + a.length),
      973,
    );
    expect(TurkishLocations.provinces, source['provinces']);
    for (final districts in TurkishLocations.provinces.values) {
      expect(districts.toSet().length, districts.length);
      expect(
        districts.every(
          (name) => name.isNotEmpty && !RegExp(r'^\d+$').hasMatch(name),
        ),
        isTrue,
      );
    }
    expect(TurkishLocations.districtsFor('Şanlıurfa').length, 13);
    expect(TurkishLocations.districtsFor('Kayseri').length, 16);
    expect(TurkishLocations.districtsFor('İstanbul').length, 39);
    expect(TurkishLocations.districtsFor('Ankara'), contains('Kahramankazan'));
    expect(TurkishLocations.districtsFor('Samsun'), contains('19 Mayıs'));
  });

  testWidgets('boş gruptaki Yenile listeyi yeniler, oluşturma formu açmaz', (
    tester,
  ) async {
    final api = CommunityTestApi();
    await tester.pumpWidget(
      MaterialApp(home: CommunityScreen(apiService: api)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Yenile'));
    await tester.tap(find.text('Yenile'));
    await tester.pumpAndSettle();
    expect(api.groupCalls, 2);
    expect(api.friendCalls, 1);
    expect(find.byType(CreateCommunityGroupSheet), findsNothing);
    await tester.tap(find.byTooltip('Topluluğu yenile'));
    await tester.pumpAndSettle();
    expect(api.groupCalls, 3);
    expect(api.friendCalls, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('grup araması sosyal endpointleri tekrar çağırmaz', (
    tester,
  ) async {
    final api = CommunityTestApi();
    await tester.pumpWidget(
      MaterialApp(home: CommunityScreen(apiService: api)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Talas');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(api.groupCalls, 2);
    expect(api.friendCalls, 1);
    expect(api.requestCalls, 1);
    expect(api.inviteCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('geç gelen kullanıcı araması yeni sonuçları ezmez', (
    tester,
  ) async {
    final api = CommunityTestApi();
    await tester.pumpWidget(
      MaterialApp(home: CommunityScreen(apiService: api)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Arkadaşlar'));
    await tester.pumpAndSettle();
    final search = find.widgetWithText(TextField, 'Ad veya kullanıcı adı ara');
    await tester.enterText(search, 'abc');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.enterText(search, 'def');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    api.searches['def']!.complete([discovery(2, 'Yeni Sonuç')]);
    await tester.pump();
    api.searches['abc']!.complete([discovery(3, 'Eski Sonuç')]);
    await tester.pumpAndSettle();
    expect(find.text('Yeni Sonuç'), findsOneWidget);
    expect(find.text('Eski Sonuç'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'açılmamış sosyal sekmelerin hatası kontrolsüz exception üretmez',
    (tester) async {
      final api = CommunityTestApi(failSocial: true);
      await tester.pumpWidget(
        MaterialApp(home: CommunityScreen(apiService: api)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Arkadaşlar'));
      await tester.pumpAndSettle();
      expect(find.text('Arkadaşlık istekleri yüklenemedi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('18 yaş altı topluluk kilidinde sosyal istek gönderilmez', (
    tester,
  ) async {
    final api = CommunityTestApi(adult: false);
    await tester.pumpWidget(
      MaterialApp(home: CommunityScreen(apiService: api)),
    );
    await tester.pumpAndSettle();
    expect(
      api.groupCalls + api.friendCalls + api.requestCalls + api.inviteCalls,
      0,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('kayıtta il/ilçe boş başlar ve il değişince ilçe temizlenir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(home: RegisterScreen(apiService: CommunityTestApi())),
    );
    final fields = find.byType(DropdownButtonFormField<String>);
    await tester.scrollUntilVisible(
      fields.first,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    var province = tester.widget<DropdownButtonFormField<String>>(fields.first);
    expect(province.initialValue, isNull);
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: fields.first,
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!
          .length,
      81,
    );
    province.onChanged!('Şanlıurfa');
    await tester.pump();
    final district = tester.widget<DropdownButtonFormField<String>>(
      fields.at(1),
    );
    expect(district.initialValue, isNull);
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: fields.at(1),
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!
          .length,
      13,
    );
    district.onChanged!('Siverek');
    await tester.pump();
    province = tester.widget<DropdownButtonFormField<String>>(fields.first);
    province.onChanged!('Kayseri');
    await tester.pump();
    expect(
      tester.widget<DropdownButtonFormField<String>>(fields.at(1)).initialValue,
      isNull,
    );
    expect(
      tester
          .widget<DropdownButton<String>>(
            find.descendant(
              of: fields.at(1),
              matching: find.byType(DropdownButton<String>),
            ),
          )
          .items!
          .length,
      16,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'profil düzenleme üç il ile sınırlı değildir ve kayıtlı mahalle korunur',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: EditProfileScreen(apiService: _LocationEditApi())),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(DropdownButtonFormField<String>);
      await tester.scrollUntilVisible(
        fields.first,
        350,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(fields.first)
            .initialValue,
        'İstanbul',
      );
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(fields.at(1))
            .initialValue,
        'Beylikdüzü',
      );
        final neighborhood = tester
            .widgetList<TextField>(find.byType(TextField))
          .where((field) => field.decoration?.labelText == 'Mahalle')
          .single;
      expect(neighborhood.controller!.text, 'Kayıtlı mahalle');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _LocationEditApi extends CommunityTestApi {
  @override
  Future<UserProfile> fetchCurrentUser() async => const UserProfile(
    id: 1,
    name: 'Test',
    surname: 'User',
    email: 'test@ecovision.invalid',
    totalPoints: 0,
    role: 'USER',
    city: 'İstanbul',
    district: 'Beylikdüzü',
    neighborhood: 'Kayıtlı mahalle',
    ownedMarketItems: {},
    adult: true,
    age: 25,
  );
}

UserDiscovery discovery(int id, String name) => UserDiscovery(
  id: id,
  username: 'user$id',
  fullName: name,
  city: 'Kayseri',
  avatarLevel: 1,
  profileVisibility: 'PUBLIC',
);

class CommunityTestApi extends ApiService {
  CommunityTestApi({this.adult = true, this.failSocial = false});
  final bool adult, failSocial;
  int groupCalls = 0, friendCalls = 0, requestCalls = 0, inviteCalls = 0;
  final searches = <String, Completer<List<UserDiscovery>>>{};
  @override
  UserProfile? get currentUser => UserProfile(
    id: 1,
    name: 'Test',
    surname: 'User',
    email: 'test@ecovision.invalid',
    totalPoints: 0,
    role: 'USER',
    city: 'Kayseri',
    ownedMarketItems: const {},
    adult: adult,
  );
  @override
  Future<List<CommunityGroup>> fetchCommunityGroups({
    String query = '',
    Set<String> cities = const {},
    String? district,
  }) async {
    groupCalls++;
    return [];
  }

  @override
  Future<List<SocialUser>> fetchFriends() async {
    friendCalls++;
    if (failSocial) throw const ApiException('Çevrimdışı');
    return [];
  }

  @override
  Future<List<FriendRequest>> fetchFriendRequests() async {
    requestCalls++;
    if (failSocial) throw const ApiException('Çevrimdışı');
    return [];
  }

  @override
  Future<List<GroupInviteModel>> fetchGroupInvites() async {
    inviteCalls++;
    if (failSocial) throw const ApiException('Çevrimdışı');
    return [];
  }

  @override
  Future<List<UserDiscovery>> searchUsers(String query) =>
      (searches[query] = Completer<List<UserDiscovery>>()).future;
}
