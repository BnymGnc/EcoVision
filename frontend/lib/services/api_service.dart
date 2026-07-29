import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/chat_message.dart';
import '../models/academy_module.dart';
import '../models/avatar_tier.dart';
import '../models/cleanup_event.dart';
import '../models/community_group.dart';
import '../models/gamification_state.dart';
import '../models/leaderboard_entry.dart';
import '../models/group_mission.dart';
import '../models/event_member.dart';
import '../models/group_waste_report.dart';
import '../models/group_join_request.dart';
import '../models/map_pin.dart';
import '../models/scan_result.dart';
import '../models/user_profile.dart';
import '../models/social_models.dart';
import '../models/app_notification.dart';
import '../models/moderation_report.dart';
import '../models/quest_progress.dart';

class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ecovision-backend-wdr0.onrender.com',
  );
  static String get productionBaseUrl =>
      _configuredBaseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
  static const _accessTokenKey = 'ecovision.access_token';
  static const _refreshTokenKey = 'ecovision.refresh_token';
  static const _googleWebClientId =
      'dummy-client-id.apps.googleusercontent.com';

  final http.Client _client;
  final FlutterSecureStorage _secureStorage;
  final ValueNotifier<int> _pointsNotifier = ValueNotifier<int>(0);

  String? _accessToken;
  String? _refreshToken;
  bool _rememberMe = true;
  UserProfile? _currentUser;
  static bool _googleInitialized = false;

  ApiService({http.Client? client, FlutterSecureStorage? secureStorage})
    : _client = client ?? http.Client(),
      _secureStorage = secureStorage ?? const FlutterSecureStorage();

  ValueListenable<int> get pointsListenable => _pointsNotifier;
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _accessToken != null;
  String? get authorizationHeader =>
      _accessToken == null ? null : 'Bearer $_accessToken';
  String get webSocketUrl {
    final base = productionBaseUrl;
    if (base.startsWith('https://')) {
      return '${base.replaceFirst('https://', 'wss://')}/ws';
    }
    return '${base.replaceFirst('http://', 'ws://')}/ws';
  }

  void setRememberMe(bool value) {
    _rememberMe = value;
  }

  Future<void> loadStoredSession() async {
    _accessToken = await _secureStorage.read(key: _accessTokenKey);
    _refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    if (_accessToken != null || _refreshToken != null) {
      try {
        await fetchCurrentUser();
      } catch (_) {
        await logout();
      }
    }
  }

  Future<bool> login({required String email, required String password}) async {
    final response = await _postJson('/api/auth/login', {
      'email': email.trim(),
      'password': password,
    }, authenticated: false);
    await _persistAuthResponse(response);
    return true;
  }

  Future<bool> register({
    required String name,
    required String surname,
    required String email,
    required String password,
    int? age,
    DateTime? dateOfBirth,
    String? city,
    String? district,
    bool termsAccepted = false,
    bool privacyAccepted = false,
  }) async {
    final birthDate =
        dateOfBirth ?? DateTime(DateTime.now().year - (age ?? 13), 1, 1);
    final response = await _postJson('/api/auth/register', {
      'name': name.trim(),
      'surname': surname.trim(),
      'email': email.trim(),
      'password': password,
      'dateOfBirth':
          '${birthDate.year.toString().padLeft(4, '0')}-'
          '${birthDate.month.toString().padLeft(2, '0')}-'
          '${birthDate.day.toString().padLeft(2, '0')}',
      if (city != null) 'city': city,
      if (district != null) 'district': district,
      'termsAccepted': termsAccepted,
      'privacyAccepted': privacyAccepted,
    }, authenticated: false);
    await _persistAuthResponse(response);
    return true;
  }

  Future<bool> loginWithGoogle() async {
    await _initializeGoogleSignIn();
    if (!GoogleSignIn.instance.supportsAuthenticate()) {
      throw ApiException('Google ile giriş bu platformda desteklenmiyor.');
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw ApiException('Google geçerli bir kimlik anahtarı döndürmedi.');
    }

    final names = _splitDisplayName(account.displayName);
    final response = await _postJson('/api/auth/google', {
      'idToken': idToken,
      'email': account.email,
      'name': names.$1,
      'surname': names.$2,
      'profilePictureUrl': account.photoUrl,
    }, authenticated: false);

    await _persistAuthResponse(response);
    return true;
  }

  Future<void> logout() async {
    final refreshToken = _refreshToken;
    if (refreshToken != null) {
      try {
        await _client.post(
          _uri('/api/auth/logout'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refreshToken}),
        );
      } catch (_) {
        // Local token destruction remains authoritative for logout.
      }
    }
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    _accessToken = null;
    _refreshToken = null;
    _currentUser = null;
    _pointsNotifier.value = 0;
    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
  }

  Future<void> requestPasswordReset(String email) async {
    await _postJson('/api/auth/forgot-password', {
      'email': email.trim(),
    }, authenticated: false);
  }

  Future<UserProfile> fetchCurrentUser() async {
    final json = await _getJson('/api/auth/me');
    return _applyUser(json);
  }

  Future<UserProfile> updateProfile({
    required String name,
    required String surname,
    required int? age,
    required String city,
    required String district,
    required String neighborhood,
  }) async {
    final json = await _putJson('/api/users/profile', {
      'name': name.trim(),
      'surname': surname.trim(),
      'age': age,
      'city': city.trim(),
      'district': district.trim(),
      'neighborhood': neighborhood.trim(),
    });
    return _applyUser(json);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _putJson('/api/users/password', {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<List<LeaderboardEntry>> fetchCityLeaderboard() async {
    final json = await _getJsonList('/api/leaderboard/city');
    return json.map(LeaderboardEntry.fromJson).toList();
  }

  Future<List<LeaderboardEntry>> fetchFriendsLeaderboard() async {
    final json = await _getJsonList('/api/leaderboard/friends');
    return json.map(LeaderboardEntry.fromJson).toList();
  }

  Future<UserProfile> updateProfileVisibility(String visibility) async {
    final json = await _putJson('/api/users/privacy', {
      'visibility': visibility,
    });
    return _applyUser(json);
  }

  Future<UserProfile> updateThemePreference(String themePreference) async {
    final json = await _putJson('/api/users/theme', {
      'themePreference': themePreference,
    });
    return _applyUser(json);
  }

  Future<UserProfile> purchaseMarketItem(String itemId) async {
    final json = await _postJson('/api/market/purchase/$itemId', const {});
    return _applyUser(json);
  }

  Future<UserProfile> uploadProfilePicture({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final response = await _authorizedMultipart(() {
      final request = http.MultipartRequest(
        'POST',
        _uri('/api/users/profile-picture'),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: fileName,
          contentType: _imageMediaType(bytes, fileName),
        ),
      );
      return request;
    });
    return _applyUser(_decodeResponse(response));
  }

  Future<ScanResult> analyzeWasteImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final response = await _authorizedMultipart(() {
      final request = http.MultipartRequest('POST', _uri('/api/scans/analyze'));
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: fileName,
          contentType: _imageMediaType(bytes, fileName),
        ),
      );
      return request;
    }, timeout: const Duration(seconds: 40));
    final json = _decodeResponse(response);
    final result = ScanResult.fromGeminiJson(json);
    final updatedPoints = json['updated_user_points'];
    if (updatedPoints is num) {
      _pointsNotifier.value = updatedPoints.toInt();
    } else {
      await fetchCurrentUser();
    }
    return result;
  }

  Future<http.Response> _authorizedMultipart(
    http.MultipartRequest Function() requestFactory, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    if (_accessToken == null && !await _refreshSession()) {
      throw const ApiException('Bu işlem için giriş yapmalısınız.');
    }

    Future<http.Response> send() async {
      Future<http.Response> execute() async {
        final request = requestFactory();
        request.headers.addAll(_authHeaders(includeJson: false));
        return http.Response.fromStream(await _client.send(request));
      }

      return execute().timeout(
        timeout,
        onTimeout: () => throw const ApiException(
          'Sunucu yanıt vermedi. Bağlantınızı kontrol edip tekrar deneyin.',
        ),
      );
    }

    var response = await send();
    if (response.statusCode == 401 && await _refreshSession()) {
      response = await send();
    }
    return response;
  }

  Future<int> getUserPoints() async {
    final user = await fetchCurrentUser();
    return user.totalPoints;
  }

  Future<List<ScanResult>> getRecentScans() async {
    final json = await _getJsonList('/api/scans');
    return json.map((item) => ScanResult.fromJson(item)).toList();
  }

  Future<GamificationState> fetchGamificationState() async {
    final json = await _getJson('/api/gamification');
    return _applyGamificationState(json);
  }

  Future<Set<String>> fetchEducationProgress() async {
    final response = await _authorizedRequest(
      (headers) =>
          _client.get(_uri('/api/education/progress'), headers: headers),
    );
    final decoded = _decodeAnyResponse(response);
    if (decoded is! List) {
      throw const ApiException(
        'Akademi ilerleme bilgisi geçersiz biçimde döndü.',
      );
    }
    return decoded
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toSet();
  }

  Future<EducationCompletionResult> completeEducationModule(
    String categoryId,
  ) async {
    final encodedCategory = Uri.encodeComponent(categoryId);
    final json = await _postJson(
      '/api/education/complete/$encodedCategory',
      const {},
    );
    final result = EducationCompletionResult.fromJson(json);
    _pointsNotifier.value = result.totalPoints;
    return result;
  }

  Future<GamificationState> completeCarbonFootprint(int score) async {
    final json = await _postJson('/api/gamification/carbon-footprint', {
      'score': score,
    });
    return _applyGamificationState(json);
  }

  Future<GamificationState> redeemReward(String rewardKey) async {
    final json = await _postJson('/api/gamification/redeem', {
      'rewardKey': rewardKey,
    });
    return _applyGamificationState(json);
  }

  Future<List<QuestProgress>> fetchQuests() async {
    final json = await _getJsonList('/api/quests');
    final quests = <QuestProgress>[];
    for (final item in json) {
      try {
        final quest = QuestProgress.fromJson(item);
        if (quest.rewardPoints > 0 && quest.targetAmount > 0) {
          quests.add(quest);
        }
      } on FormatException {
        // Ignore stale malformed records while keeping valid missions visible.
      }
    }
    if (json.isNotEmpty && quests.isEmpty) {
      throw const ApiException(
        'Görev verileri güncel değil. Lütfen biraz sonra tekrar deneyin.',
      );
    }
    return quests;
  }

  Future<QuestProgress> checkInQuest(int questId) async {
    final json = await _postJson('/api/quests/$questId/check-in', const {});
    return QuestProgress.fromJson(json);
  }

  Future<QuestClaimResult> claimQuest(int progressId) async {
    final json = await _postJson(
      '/api/quests/progress/$progressId/claim',
      const {},
    );
    final result = QuestClaimResult.fromJson(json);
    _pointsNotifier.value = result.totalPoints;
    return result;
  }

  Future<List<AvatarTier>> fetchAvatarTiers() async {
    final json = await _getJsonList('/api/gamification/avatar-tiers');
    return json.map(AvatarTier.fromJson).toList();
  }

  Future<UserProfile> equipAvatar(int level) async {
    final json = await _putJson(
      '/api/gamification/avatar/$level/equip',
      const {},
    );
    return _applyUser(json);
  }

  Future<List<CleanupEvent>> fetchEvents({
    String query = '',
    String? city,
    String? district,
    Set<String> cities = const {},
  }) async {
    final queryParameters = <String, String>{
      'query': query.trim(),
      if (city != null && city.isNotEmpty) 'city': city,
      if (district != null && district.isNotEmpty) 'district': district,
      if (cities.isNotEmpty) 'cities': cities.join(','),
    };
    final path = Uri(path: '/api/events', queryParameters: queryParameters);
    final json = await _getJsonList(path.toString());
    return json.map((item) => CleanupEvent.fromJson(item)).toList();
  }

  Future<List<CommunityGroup>> fetchCommunityGroups({
    String query = '',
    Set<String> cities = const {},
    String? district,
  }) async {
    final parameters = <String, String>{
      if (query.trim().isNotEmpty) 'query': query.trim(),
      if (cities.isNotEmpty) 'cities': cities.join(','),
      if (district != null && district.isNotEmpty) 'district': district,
    };
    final path = Uri(path: '/api/groups', queryParameters: parameters);
    final json = await _getJsonList(path.toString());
    return json.map(CommunityGroup.fromJson).toList();
  }

  Future<CommunityGroup> fetchCommunityGroup(int groupId) async {
    return CommunityGroup.fromJson(await _getJson('/api/groups/$groupId'));
  }

  Future<CommunityGroup> createCommunityGroup({
    required String name,
    required String description,
    required String city,
    required String district,
    required String neighborhood,
    required int memberLimit,
    String? joinCode,
    bool privateGroup = false,
    Uint8List? coverBytes,
    String? coverFileName,
  }) async {
    final payload = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'city': city,
      'district': district,
      'neighborhood': neighborhood.trim(),
      'memberLimit': memberLimit,
      'privateGroup': privateGroup,
      if (joinCode != null && joinCode.trim().isNotEmpty)
        'joinCode': joinCode.trim(),
    };
    if (coverBytes == null) {
      return CommunityGroup.fromJson(await _postJson('/api/groups', payload));
    }
    final response = await _authorizedMultipart(() {
      final request = http.MultipartRequest('POST', _uri('/api/groups'));
      request.files.add(
        http.MultipartFile.fromString(
          'group',
          jsonEncode(payload),
          contentType: MediaType('application', 'json'),
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'coverImage',
          coverBytes,
          filename: coverFileName ?? 'group-cover.jpg',
          contentType: _imageMediaType(coverBytes),
        ),
      );
      return request;
    });
    return CommunityGroup.fromJson(_decodeResponse(response));
  }

  Future<CommunityGroup> updateCommunityGroup({
    required int groupId,
    required String name,
    required String description,
    required String city,
    required String district,
    required String neighborhood,
    required int memberLimit,
    bool? privateGroup,
    Uint8List? coverBytes,
    String? coverFileName,
  }) async {
    final payload = {
      'name': name.trim(),
      'description': description.trim(),
      'city': city.trim(),
      'district': district.trim(),
      'neighborhood': neighborhood.trim(),
      'memberLimit': memberLimit,
      if (privateGroup != null) 'privateGroup': privateGroup,
    };
    if (coverBytes == null) {
      return CommunityGroup.fromJson(
        await _putJson('/api/groups/$groupId', payload),
      );
    }
    final response = await _authorizedMultipart(() {
      final request = http.MultipartRequest(
        'PUT',
        _uri('/api/groups/$groupId'),
      );
      request.files.add(
        http.MultipartFile.fromString(
          'group',
          jsonEncode(payload),
          contentType: MediaType('application', 'json'),
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'coverImage',
          coverBytes,
          filename: coverFileName ?? 'group-cover.jpg',
          contentType: _imageMediaType(coverBytes),
        ),
      );
      return request;
    });
    return CommunityGroup.fromJson(_decodeResponse(response));
  }

  Future<CommunityGroup> joinCommunityGroup(
    int groupId, {
    String? joinCode,
  }) async {
    final json = await _postJson('/api/groups/$groupId/join', {
      if (joinCode != null) 'joinCode': joinCode,
    });
    return CommunityGroup.fromJson(json);
  }

  Future<GroupJoinRequest> requestToJoinCommunityGroup(int groupId) async {
    return GroupJoinRequest.fromJson(
      await _postJson('/api/groups/$groupId/join-requests', const {}),
    );
  }

  Future<List<GroupJoinRequest>> fetchGroupJoinRequests(int groupId) async {
    final json = await _getJsonList('/api/groups/$groupId/join-requests');
    return json.map(GroupJoinRequest.fromJson).toList();
  }

  Future<GroupJoinRequest> reviewGroupJoinRequest({
    required int groupId,
    required int requestId,
    required bool approve,
  }) async {
    final action = approve ? 'approve' : 'reject';
    return GroupJoinRequest.fromJson(
      await _postJson(
        '/api/groups/$groupId/join-requests/$requestId/$action',
        const {},
      ),
    );
  }

  Future<void> leaveCommunityGroup(int groupId) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/groups/$groupId/membership'),
        headers: headers,
      ),
    );
    if (response.statusCode != 204) _decodeAnyResponse(response);
  }

  Future<CommunityGroup> resolveGroupInvite(String inviteCode) async {
    return CommunityGroup.fromJson(
      await _getJson('/api/groups/invite/${Uri.encodeComponent(inviteCode)}'),
    );
  }

  Future<CommunityGroup> joinCommunityGroupByInvite(String inviteCode) async {
    return CommunityGroup.fromJson(
      await _postJson(
        '/api/groups/invite/${Uri.encodeComponent(inviteCode.trim())}/join',
        const {},
      ),
    );
  }

  Future<List<EventMember>> fetchCommunityGroupMembers(int groupId) async {
    final json = await _getJsonList('/api/groups/$groupId/members');
    return json.map(EventMember.fromJson).toList();
  }

  Future<EventMember> addCommunityGroupMember(
    int groupId,
    String username,
  ) async {
    final json = await _postJson('/api/groups/$groupId/members', {
      'username': username.trim(),
    });
    return EventMember.fromJson(json);
  }

  Future<EventMember> promoteCommunityGroupAdmin(
    int groupId,
    int userId,
  ) async {
    final json = await _postJson(
      '/api/groups/$groupId/members/$userId/admin',
      const {},
    );
    return EventMember.fromJson(json);
  }

  Future<EventMember> demoteCommunityGroupAdmin(int groupId, int userId) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/groups/$groupId/members/$userId/admin'),
        headers: headers,
      ),
    );
    return EventMember.fromJson(_decodeResponse(response));
  }

  Future<void> removeCommunityGroupMember(int groupId, int userId) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/groups/$groupId/members/$userId'),
        headers: headers,
      ),
    );
    if (response.statusCode != 204) {
      _decodeAnyResponse(response);
    }
  }

  Future<void> deleteCommunityGroup(int groupId) async {
    final response = await _authorizedRequest(
      (headers) =>
          _client.delete(_uri('/api/groups/$groupId'), headers: headers),
    );
    if (response.statusCode != 204) {
      _decodeAnyResponse(response);
    }
  }

  Future<List<GroupEvent>> fetchGroupEvents(int groupId) async {
    final json = await _getJsonList('/api/groups/$groupId/events');
    return json.map(GroupEvent.fromJson).toList();
  }

  Future<GroupEvent> createGroupEvent({
    required int groupId,
    required String title,
    required String description,
    required DateTime eventDate,
    required String city,
    required String district,
    required String exactAddress,
    required int capacity,
    Uint8List? coverBytes,
    String? coverFileName,
  }) async {
    final payload = {
      'title': title.trim(),
      'description': description.trim(),
      'eventDate': eventDate.toUtc().toIso8601String(),
      'city': city,
      'district': district,
      'exactAddress': exactAddress.trim(),
      'capacity': capacity,
    };
    if (coverBytes == null) {
      return GroupEvent.fromJson(
        await _postJson('/api/groups/$groupId/events', payload),
      );
    }
    final response = await _authorizedMultipart(() {
      final request = http.MultipartRequest(
        'POST',
        _uri('/api/groups/$groupId/events'),
      );
      request.files.add(
        http.MultipartFile.fromString(
          'event',
          jsonEncode(payload),
          contentType: MediaType('application', 'json'),
        ),
      );
      if (coverBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'coverImage',
            coverBytes,
            filename: coverFileName ?? 'event-cover.jpg',
            contentType: _imageMediaType(coverBytes),
          ),
        );
      }
      return request;
    });
    return GroupEvent.fromJson(_decodeResponse(response));
  }

  Future<GroupEvent> updateGroupEventRsvp({
    required int groupId,
    required int eventId,
    required String status,
  }) async {
    final json = await _postJson('/api/groups/$groupId/events/$eventId/rsvp', {
      'status': status,
    });
    return GroupEvent.fromJson(json);
  }

  Future<GroupEvent> leaveGroupEvent({
    required int groupId,
    required int eventId,
  }) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/groups/$groupId/events/$eventId/rsvp'),
        headers: headers,
      ),
    );
    return GroupEvent.fromJson(_decodeResponse(response));
  }

  Future<CommunityGroup> pinGroupContent({
    required int groupId,
    required String type,
    int? id,
  }) async {
    final json = await _putJson('/api/groups/$groupId/pin', {
      'type': type,
      if (id != null) 'id': id,
    });
    return CommunityGroup.fromJson(json);
  }

  Future<List<EventMember>> fetchGroupEventAttendees({
    required int groupId,
    required int eventId,
  }) async {
    final json = await _getJsonList(
      '/api/groups/$groupId/events/$eventId/attendees',
    );
    return json.map(EventMember.fromJson).toList();
  }

  Future<void> deleteGroupEvent({
    required int groupId,
    required int eventId,
  }) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/groups/$groupId/events/$eventId'),
        headers: headers,
      ),
    );
    if (response.statusCode != 204) {
      _decodeAnyResponse(response);
    }
  }

  Future<CleanupEvent> joinEvent(int eventId, {String? joinCode}) async {
    final json = await _postJson('/api/events/$eventId/join', {
      if (joinCode != null) 'joinCode': joinCode,
    });
    return CleanupEvent.fromJson(json);
  }

  Future<List<EventMember>> fetchEventMembers(int eventId) async {
    final json = await _getJsonList('/api/events/$eventId/members');
    return json.map(EventMember.fromJson).toList();
  }

  Future<EventMember> promoteEventAdmin(int eventId, int userId) async {
    final json = await _postJson(
      '/api/events/$eventId/members/$userId/admin',
      const {},
    );
    return EventMember.fromJson(json);
  }

  Future<void> removeEventMember(int eventId, int userId) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/events/$eventId/members/$userId'),
        headers: headers,
      ),
    );
    if (response.statusCode != 204) {
      _decodeAnyResponse(response);
    }
  }

  Future<CleanupEvent> updateEventRsvp(int eventId, String status) async =>
      CleanupEvent.fromJson(
        await _putJson('/api/events/$eventId/rsvp', {'status': status}),
      );

  Future<List<EventMember>> fetchEventAttendees(int eventId) async {
    final json = await _getJsonList('/api/events/$eventId/attendees');
    return json.map(EventMember.fromJson).toList();
  }

  Future<List<GroupWasteReport>> fetchGroupWasteReports(int eventId) async {
    final json = await _getJsonList('/api/events/$eventId/waste-reports');
    return json.map(GroupWasteReport.fromJson).toList();
  }

  Future<GroupWasteReport> createGroupWasteReport({
    required int eventId,
    required String materialType,
    required int itemCount,
  }) async {
    final json = await _postJson('/api/events/$eventId/waste-reports', {
      'materialType': materialType,
      'itemCount': itemCount,
    });
    return GroupWasteReport.fromJson(json);
  }

  Future<List<GroupMission>> fetchGroupMissions(int eventId) async {
    final json = await _getJsonList('/api/events/$eventId/missions');
    return json.map(GroupMission.fromJson).toList();
  }

  Future<GroupMission> createGroupMission({
    required int eventId,
    required String title,
    required int targetAmount,
    required String unit,
  }) async {
    final json = await _postJson('/api/events/$eventId/missions', {
      'title': title.trim(),
      'targetAmount': targetAmount,
      'unit': unit.trim(),
    });
    return GroupMission.fromJson(json);
  }

  Future<void> deleteEvent(int eventId) async {
    final response = await _client.delete(
      _uri('/api/events/$eventId'),
      headers: _authHeaders(),
    );
    if (response.statusCode != 204) {
      _decodeAnyResponse(response);
    }
  }

  Future<List<UserProfile>> fetchAdminUsers() async {
    final json = await _getJsonList('/api/admin/users');
    return json.map((item) => UserProfile.fromJson(item)).toList();
  }

  Future<UserProfile> assignAdminRole(String email) async {
    final json = await _postJson('/api/admin/assign-admin', {
      'email': email.trim(),
    });
    return UserProfile.fromJson(json);
  }

  Future<List<MapPin>> fetchMapPins() async {
    final json = await _getJsonList('/api/map-pins');
    return json.map((item) => MapPin.fromJson(item)).toList();
  }

  Future<List<MapPin>> fetchNearestMapPins({
    required double latitude,
    required double longitude,
    double? radiusKm,
    int? limit,
    Set<String> materials = const {},
  }) async {
    final query = <String, String>{
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      if (radiusKm != null) 'radiusKm': radiusKm.toString(),
      if (limit != null) 'limit': limit.toString(),
      if (materials.isNotEmpty) 'materials': materials.join(','),
    };
    final uri = _uri('/api/map-pins/nearest').replace(queryParameters: query);
    final response = await _client.get(uri, headers: _authHeaders());
    final decoded = _decodeAnyResponse(response);
    if (decoded is List) {
      return decoded
          .cast<Map<String, dynamic>>()
          .map((item) => MapPin.fromJson(item))
          .toList();
    }
    throw ApiException('Expected a list response from nearest pins.');
  }

  Future<MapPin> addOfficialMapPin({
    required String title,
    required double latitude,
    required double longitude,
  }) async {
    final json = await _postJson('/api/admin/map-pins', {
      'title': title,
      'latitude': latitude,
      'longitude': longitude,
    });
    return MapPin.fromJson(json);
  }

  Future<CleanupEvent> createCleanupEvent({
    required String title,
    required String description,
    required String city,
    required String district,
    required String neighborhood,
    required DateTime eventDate,
    String exactAddress = '',
    int memberLimit = 20,
    String? joinCode,
    Uint8List? coverBytes,
    String? coverFileName,
  }) async {
    final payload = {
      'title': title,
      'description': description,
      'city': city,
      'district': district,
      'neighborhood': neighborhood,
      'eventDate': eventDate.toUtc().toIso8601String(),
      'eventTime':
          '${eventDate.hour.toString().padLeft(2, '0')}:'
          '${eventDate.minute.toString().padLeft(2, '0')}',
      'exactAddress': exactAddress.trim().isEmpty
          ? '$neighborhood, $district/$city'
          : exactAddress.trim(),
      'memberLimit': memberLimit,
      if (joinCode != null && joinCode.trim().isNotEmpty)
        'joinCode': joinCode.trim(),
    };
    if (coverBytes == null) {
      return CleanupEvent.fromJson(await _postJson('/api/events', payload));
    }

    final request = http.MultipartRequest('POST', _uri('/api/events'));
    request.headers.addAll(_authHeaders(includeJson: false));
    request.files.add(
      http.MultipartFile.fromString(
        'event',
        jsonEncode(payload),
        contentType: MediaType('application', 'json'),
      ),
    );
    request.files.add(
      http.MultipartFile.fromBytes(
        'coverImage',
        coverBytes,
        filename: coverFileName ?? 'event-cover.jpg',
        contentType: _imageMediaType(coverBytes),
      ),
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return CleanupEvent.fromJson(_decodeResponse(response));
  }

  Future<List<ChatMessage>> fetchMessages(
    int eventId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final json = await _getJsonList(
      '/api/chat/events/$eventId?limit=$limit&offset=$offset',
    );
    return json.map((item) => ChatMessage.fromJson(item)).toList();
  }

  Future<List<ChatMessage>> fetchGroupMessages(
    int groupId, {
    int limit = 30,
    int offset = 0,
  }) async {
    final json = await _getJsonList(
      '/api/chat/groups/$groupId?limit=$limit&offset=$offset',
    );
    return json.map(ChatMessage.fromJson).toList();
  }

  Future<ChatMessage> sendGroupMessage({
    required int groupId,
    required String message,
    int? replyToMessageId,
  }) async {
    final json = await _postJson('/api/chat/groups/$groupId', {
      'message': message,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    });
    return ChatMessage.fromJson(json);
  }

  Future<ChatMessage> sendGroupChatAttachment({
    required int groupId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    int? replyToMessageId,
  }) async {
    if (bytes.length > 2 * 1024 * 1024) {
      throw const ApiException('Ek dosya 2 MB\'den küçük olmalıdır.');
    }
    final response = await _authorizedMultipart(() {
      final request = http.MultipartRequest(
        'POST',
        _uri('/api/chat/groups/$groupId/attachments').replace(
          queryParameters: {
            if (replyToMessageId != null)
              'replyToMessageId': '$replyToMessageId',
          },
        ),
      );
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );
      return request;
    });
    return ChatMessage.fromJson(_decodeResponse(response));
  }

  Future<List<ChatMessage>> fetchGroupMedia(
    int groupId, {
    int limit = 60,
    int offset = 0,
  }) async {
    final json = await _getJsonList(
      '/api/chat/groups/$groupId/media?limit=$limit&offset=$offset',
    );
    return json.map(ChatMessage.fromJson).toList();
  }

  Future<ChatMessage> reactToGroupMessage({
    required int groupId,
    required int messageId,
    required String emoji,
  }) async {
    return ChatMessage.fromJson(
      await _postJson(
        '/api/chat/groups/$groupId/messages/$messageId/reactions',
        {'emoji': emoji},
      ),
    );
  }

  Future<ChatMessage> deleteGroupMessage({
    required int groupId,
    required int messageId,
  }) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(
        _uri('/api/chat/groups/$groupId/messages/$messageId'),
        headers: headers,
      ),
    );
    return ChatMessage.fromJson(_decodeResponse(response));
  }

  Future<ChatMessage> createGroupPoll({
    required int groupId,
    required String question,
    required List<String> options,
  }) async {
    return ChatMessage.fromJson(
      await _postJson('/api/chat/groups/$groupId/polls', {
        'question': question.trim(),
        'options': options.map((option) => option.trim()).toList(),
      }),
    );
  }

  Future<ChatMessage> voteInGroupPoll({
    required int groupId,
    required int messageId,
    required int optionIndex,
  }) async {
    return ChatMessage.fromJson(
      await _postJson('/api/chat/groups/$groupId/messages/$messageId/vote', {
        'optionIndex': optionIndex,
      }),
    );
  }

  Future<int> fetchUnreadCommunityCount() async {
    final json = await _getJson('/api/chat/unread-count');
    return (json['count'] as num? ?? 0).toInt();
  }

  Future<void> markCommunityRead() async {
    await _postJson('/api/chat/read', const {});
  }

  Future<ChatMessage> sendMessage({
    required int eventId,
    required String message,
  }) async {
    final json = await _postJson('/api/chat/events/$eventId', {
      'message': message,
    });
    return ChatMessage.fromJson(json);
  }

  Future<ChatMessage> sendChatImage({
    required int eventId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.length > 2 * 1024 * 1024)
      throw const ApiException('Fotoğraf 2 MB\'den küçük olmalıdır.');
    return sendChatAttachment(
      eventId: eventId,
      bytes: bytes,
      fileName: fileName,
      contentType: 'image/jpeg',
    );
  }

  Future<ChatMessage> sendChatAttachment({
    required int eventId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    if (bytes.length > 2 * 1024 * 1024) {
      throw const ApiException('Ek dosya 2 MB\'den küçük olmalıdır.');
    }
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/chat/events/$eventId/attachments'),
    );
    request.headers.addAll(_authHeaders(includeJson: false));
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ),
    );
    final response = await http.Response.fromStream(
      await _client.send(request),
    );
    return ChatMessage.fromJson(_decodeResponse(response));
  }

  Future<PublicProfile> fetchPublicProfile(int userId) async =>
      PublicProfile.fromJson(await _getJson('/api/social/users/$userId'));

  MediaType _imageMediaType(Uint8List bytes, [String? fileName]) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return MediaType('image', 'png');
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return MediaType('image', 'webp');
    }
    if (bytes.length >= 12 &&
        bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      final brand = String.fromCharCodes(bytes.sublist(8, 12)).toLowerCase();
      if (brand == 'heic' ||
          brand == 'heix' ||
          brand == 'hevc' ||
          brand == 'hevx') {
        return MediaType('image', 'heic');
      }
      if (brand == 'heif' || brand == 'mif1' || brand == 'msf1') {
        return MediaType('image', 'heif');
      }
    }
    final extension = (fileName ?? '').toLowerCase();
    if (extension.endsWith('.heic')) return MediaType('image', 'heic');
    if (extension.endsWith('.heif')) return MediaType('image', 'heif');
    return MediaType('image', 'jpeg');
  }

  Future<void> likeProfile(int userId) async =>
      _postJson('/api/social/users/$userId/like', const {});
  Future<void> unlikeProfile(int userId) async =>
      _deleteJson('/api/social/users/$userId/like');
  Future<void> sendFriendRequest(int userId) async =>
      _postJson('/api/social/friends/$userId/request', const {});
  Future<List<UserDiscovery>> searchUsers(String query) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final json = await _getJsonList('/api/social/users/search?query=$encoded');
    return json.map(UserDiscovery.fromJson).toList();
  }

  Future<List<SocialUser>> fetchFriends() async => (await _getJsonList(
    '/api/social/friends',
  )).map(SocialUser.fromJson).toList();
  Future<List<FriendRequest>> fetchFriendRequests() async =>
      (await _getJsonList(
        '/api/social/friends/requests',
      )).map(FriendRequest.fromJson).toList();
  Future<void> acceptFriendRequest(int id) async =>
      _postJson('/api/social/friends/requests/$id/accept', const {});
  Future<void> rejectFriendRequest(int id) async =>
      _postJson('/api/social/friends/requests/$id/reject', const {});
  Future<void> removeFriend(int userId) async =>
      _deleteJson('/api/social/friends/$userId');
  Future<List<GroupInviteModel>> fetchGroupInvites() async =>
      (await _getJsonList(
        '/api/social/group-invites',
      )).map(GroupInviteModel.fromJson).toList();
  Future<void> inviteFriendToGroup(int eventId, int friendId) async =>
      _postJson('/api/social/groups/$eventId/invites/$friendId', const {});
  Future<void> acceptGroupInvite(int id) async =>
      _postJson('/api/social/group-invites/$id/accept', const {});
  Future<void> reportUser(int userId, String reason) async =>
      _postJson('/api/social/reports/users/$userId', {'reason': reason});
  Future<void> reportGroup(int eventId, String reason) async =>
      _postJson('/api/social/reports/groups/$eventId', {'reason': reason});
  Future<void> blockUser(int userId) async =>
      _postJson('/api/social/blocks/$userId', const {});
  Future<void> unblockUser(int userId) async =>
      _deleteJson('/api/social/blocks/$userId');

  Future<List<AppNotification>> fetchNotifications({int limit = 50}) async =>
      (await _getJsonList(
        '/api/notifications?limit=$limit',
      )).map(AppNotification.fromJson).toList();
  Future<int> fetchUnreadNotificationCount() async =>
      ((await _getJson('/api/notifications/unread-count'))['count'] as num? ??
              0)
          .toInt();
  Future<void> markAllNotificationsRead() async {
    await _postJson('/api/notifications/read-all', const {});
  }

  Future<List<ModerationReport>> fetchModerationReports() async =>
      (await _getJsonList(
        '/api/superuser/reports',
      )).map(ModerationReport.fromJson).toList();
  Future<List<ChatMessage>> auditGroupChat(int groupId) async =>
      (await _getJsonList(
        '/api/superuser/audit/chat/$groupId',
      )).map(ChatMessage.fromJson).toList();
  Future<List<ChatMessage>> auditUserChat(int userId) async =>
      (await _getJsonList(
        '/api/superuser/audit/user/$userId',
      )).map(ChatMessage.fromJson).toList();
  Future<int> sendGlobalBroadcast({
    required String title,
    required String message,
  }) async =>
      ((await _postJson('/api/superuser/broadcast', {
                    'title': title.trim(),
                    'message': message.trim(),
                  }))['recipients']
                  as num? ??
              0)
          .toInt();
  Future<UserProfile> banUser(int userId) async => UserProfile.fromJson(
    await _postJson('/api/superuser/users/$userId/ban', const {}),
  );
  Future<UserProfile> unbanUser(int userId) async => UserProfile.fromJson(
    await _postJson('/api/superuser/users/$userId/unban', const {}),
  );
  Future<UserProfile> suspendUser(int userId, int days) async =>
      UserProfile.fromJson(
        await _postJson('/api/superuser/users/$userId/suspend', {'days': days}),
      );
  Future<void> superuserDeleteGroup(int groupId) async {
    final response = await _client.delete(
      _uri('/api/superuser/groups/$groupId'),
      headers: _authHeaders(),
    );
    if (response.statusCode != 204) _decodeAnyResponse(response);
  }

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _authorizedRequest(
      (headers) => _client.get(_uri(path), headers: headers),
    );
    return _decodeResponse(response);
  }

  GamificationState _applyGamificationState(Map<String, dynamic> json) {
    final state = GamificationState.fromJson(json);
    _pointsNotifier.value = state.totalPoints;
    return state;
  }

  UserProfile _applyUser(Map<String, dynamic> json) {
    final user = UserProfile.fromJson(json);
    _currentUser = user;
    _pointsNotifier.value = user.totalPoints;
    return user;
  }

  Future<List<Map<String, dynamic>>> _getJsonList(String path) async {
    final response = await _authorizedRequest(
      (headers) => _client.get(_uri(path), headers: headers),
    );
    final decoded = _decodeAnyResponse(response);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw ApiException('$path için liste yanıtı alınamadı.');
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body, {
    bool authenticated = true,
  }) async {
    final response = authenticated
        ? await _authorizedRequest(
            (headers) => _client.post(
              _uri(path),
              headers: headers,
              body: jsonEncode(body),
            ),
          )
        : await _client.post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _authorizedRequest(
      (headers) =>
          _client.put(_uri(path), headers: headers, body: jsonEncode(body)),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final response = await _authorizedRequest(
      (headers) => _client.delete(_uri(path), headers: headers),
    );
    return _decodeResponse(response);
  }

  Object? _decodeAnyResponse(http.Response response) {
    Object? decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw ApiException(
        'Sunucuya şu an ulaşılamıyor, lütfen tekrar deneyin.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? (decoded['message'] ?? 'İstek tamamlanamadı.').toString()
        : 'İstek tamamlanamadı.';
    throw ApiException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = _decodeAnyResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('Sunucudan geçerli bir nesne yanıtı alınamadı.');
  }

  Future<void> _persistAuthResponse(Map<String, dynamic> json) async {
    final accessToken = json['accessToken']?.toString();
    final refreshToken = json['refreshToken']?.toString();
    final userJson = json['user'];
    if (accessToken == null ||
        accessToken.isEmpty ||
        refreshToken == null ||
        refreshToken.isEmpty ||
        userJson is! Map<String, dynamic>) {
      throw ApiException('Kimlik doğrulama yanıtı geçersiz.');
    }

    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _currentUser = UserProfile.fromJson(userJson);
    _pointsNotifier.value = _currentUser!.totalPoints;

    if (_rememberMe) {
      await _secureStorage.write(key: _accessTokenKey, value: accessToken);
      await _secureStorage.write(key: _refreshTokenKey, value: refreshToken);
    } else {
      await _secureStorage.delete(key: _accessTokenKey);
      await _secureStorage.delete(key: _refreshTokenKey);
    }
  }

  Uri _uri(String path) => Uri.parse('$productionBaseUrl$path');

  Map<String, String> _authHeaders({bool includeJson = true}) {
    if (_accessToken == null) {
      throw ApiException('Bu işlem için giriş yapmalısınız.');
    }
    return {
      if (includeJson) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };
  }

  Future<http.Response> _authorizedRequest(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    if (_accessToken == null && !await _refreshSession()) {
      throw ApiException('Bu işlem için giriş yapmalısınız.');
    }
    var response = await request(_authHeaders());
    if (response.statusCode == 401 && await _refreshSession()) {
      response = await request(_authHeaders());
    }
    return response;
  }

  Future<bool> _refreshSession() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return false;
    }
    try {
      final response = await _client.post(
        _uri('/api/auth/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      await _persistAuthResponse(_decodeResponse(response));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    if (_googleInitialized) {
      return;
    }
    await GoogleSignIn.instance.initialize(clientId: _googleWebClientId);
    _googleInitialized = true;
  }

  (String, String) _splitDisplayName(String? displayName) {
    final parts = (displayName ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return ('Google', 'User');
    }
    if (parts.length == 1) {
      return (parts.first, 'User');
    }
    return (parts.first, parts.skip(1).join(' '));
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
