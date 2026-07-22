import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/cleanup_event.dart';
import '../models/gamification_state.dart';
import '../models/map_pin.dart';
import '../models/scan_result.dart';
import '../models/user_profile.dart';

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
      throw ApiException('Google Sign-In is not supported on this platform.');
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw ApiException('Google did not return an ID token.');
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
    _currentUser = UserProfile.fromJson(json);
    _pointsNotifier.value = _currentUser!.totalPoints;
    return _currentUser!;
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
    _currentUser = UserProfile.fromJson(json);
    _pointsNotifier.value = _currentUser!.totalPoints;
    return _currentUser!;
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

  Future<List<CleanupEvent>> fetchEvents() async {
    final json = await _getJsonList('/api/events');
    return json.map((item) => CleanupEvent.fromJson(item)).toList();
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
    required String location,
    required DateTime eventDate,
    String? photoPath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/events/multipart'),
    );
    request.headers.addAll(_authHeaders(includeJson: false));
    request.fields.addAll({
      'title': title,
      'description': description,
      'location': location,
      'eventDate': eventDate.toUtc().toIso8601String(),
    });
    if (photoPath != null) {
      request.files.add(await http.MultipartFile.fromPath('image', photoPath));
    }

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);
    return CleanupEvent.fromJson(_decodeResponse(response));
  }

  Future<List<ChatMessage>> fetchMessages(int eventId) async {
    final json = await _getJsonList('/api/chat/events/$eventId');
    return json.map((item) => ChatMessage.fromJson(item)).toList();
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

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _client.get(_uri(path), headers: _authHeaders());
    return _decodeResponse(response);
  }

  GamificationState _applyGamificationState(Map<String, dynamic> json) {
    final state = GamificationState.fromJson(json);
    _pointsNotifier.value = state.totalPoints;
    return state;
  }

  Future<List<Map<String, dynamic>>> _getJsonList(String path) async {
    final response = await _client.get(_uri(path), headers: _authHeaders());
    final decoded = _decodeAnyResponse(response);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw ApiException('Expected a list response from $path.');
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

  Object? _decodeAnyResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final message = decoded is Map<String, dynamic>
        ? (decoded['message'] ?? 'Request failed').toString()
        : 'Request failed';
    throw ApiException(message, statusCode: response.statusCode);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = _decodeAnyResponse(response);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException('Expected an object response.');
  }

  Future<void> _persistAuthResponse(Map<String, dynamic> json) async {
    final token = json['token']?.toString();
    final userJson = json['user'];
    if (token == null || token.isEmpty || userJson is! Map<String, dynamic>) {
      throw ApiException('Authentication response was invalid.');
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
      throw ApiException('You are not signed in.');
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
