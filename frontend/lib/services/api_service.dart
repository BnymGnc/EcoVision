import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/avatar_tier.dart';
import '../models/cleanup_event.dart';
import '../models/gamification_state.dart';
import '../models/leaderboard_entry.dart';
import '../models/group_mission.dart';
import '../models/event_member.dart';
import '../models/group_waste_report.dart';
import '../models/map_pin.dart';
import '../models/scan_result.dart';
import '../models/user_profile.dart';
import '../models/social_models.dart';
import '../models/app_notification.dart';
import '../models/moderation_report.dart';

class ApiService {
  static const _tokenKey = 'ecovision.jwt';
  static const _googleWebClientId =
      'dummy-client-id.apps.googleusercontent.com';

  final http.Client _client;
  final ValueNotifier<int> _pointsNotifier = ValueNotifier<int>(0);

  String? _jwt;
  UserProfile? _currentUser;
  static bool _googleInitialized = false;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  ValueListenable<int> get pointsListenable => _pointsNotifier;
  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _jwt != null;

  Future<void> loadStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    _jwt = prefs.getString(_tokenKey);
    if (_jwt != null) {
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
  }) async {
    final response = await _postJson('/api/auth/register', {
      'name': name.trim(),
      'surname': surname.trim(),
      'email': email.trim(),
      'password': password,
      'age': age,
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    _jwt = null;
    _currentUser = null;
    _pointsNotifier.value = 0;
    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
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

  Future<UserProfile> purchaseMarketItem(String itemId) async {
    final json = await _postJson('/api/market/purchase/$itemId', const {});
    return _applyUser(json);
  }

  Future<UserProfile> uploadProfilePicture(String imagePath) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/auth/me/profile-picture'),
    );
    request.headers.addAll(_authHeaders(includeJson: false));
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    final json = _decodeResponse(response);
    return _applyUser(json);
  }

  Future<ScanResult> claimScanPoints(String detectedClass) async {
    final json = await _postJson('/api/scans/analyze', {
      'detected_class': detectedClass,
    });

    final result = ScanResult.fromJson(json);
    final updatedPoints = json['updated_user_points'];
    if (updatedPoints is num) {
      _pointsNotifier.value = updatedPoints.toInt();
    } else {
      await fetchCurrentUser();
    }
    return result;
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

  Future<List<CleanupEvent>> fetchEvents({String query = ''}) async {
    final encoded = Uri.encodeQueryComponent(query.trim());
    final json = await _getJsonList('/api/events?query=$encoded');
    return json.map((item) => CleanupEvent.fromJson(item)).toList();
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
  }) async {
    final query = <String, String>{
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      if (radiusKm != null) 'radiusKm': radiusKm.toString(),
      if (limit != null) 'limit': limit.toString(),
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
    int memberLimit = 20,
    String? joinCode,
  }) async {
    final json = await _postJson('/api/events', {
      'title': title,
      'description': description,
      'city': city,
      'district': district,
      'neighborhood': neighborhood,
      'eventDate': eventDate.toUtc().toIso8601String(),
      'memberLimit': memberLimit,
      if (joinCode != null && joinCode.trim().isNotEmpty)
        'joinCode': joinCode.trim(),
    });
    return CleanupEvent.fromJson(json);
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
  Future<void> likeProfile(int userId) async =>
      _postJson('/api/social/users/$userId/like', const {});
  Future<void> unlikeProfile(int userId) async =>
      _deleteJson('/api/social/users/$userId/like');
  Future<void> sendFriendRequest(int userId) async =>
      _postJson('/api/social/friends/$userId/request', const {});
  Future<UserDiscovery> searchUserByUsername(
    String username,
  ) async => UserDiscovery.fromJson(
    await _getJson(
      '/api/social/users/search?username=${Uri.encodeQueryComponent(username.trim())}',
    ),
  );
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
    final response = await _client.get(_uri(path), headers: _authHeaders());
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
    final response = await _client.get(_uri(path), headers: _authHeaders());
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
    final response = await _client.post(
      _uri(path),
      headers: authenticated
          ? _authHeaders()
          : {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.put(
      _uri(path),
      headers: _authHeaders(),
      body: jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _deleteJson(String path) async {
    final response = await _client.delete(_uri(path), headers: _authHeaders());
    return _decodeResponse(response);
  }

  Object? _decodeAnyResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
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
    final token = json['token']?.toString();
    final userJson = json['user'];
    if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
      throw ApiException('Kimlik doğrulama yanıtı geçersiz.');
    }

    _jwt = token;
    _currentUser = UserProfile.fromJson(userJson);
    _pointsNotifier.value = _currentUser!.totalPoints;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Uri _uri(String path) => Uri.parse('${AppConstants.apiBaseUrl}$path');

  Map<String, String> _authHeaders({bool includeJson = true}) {
    if (_jwt == null) {
      throw ApiException('Bu işlem için giriş yapmalısınız.');
    }
    return {
      if (includeJson) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $_jwt',
    };
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
