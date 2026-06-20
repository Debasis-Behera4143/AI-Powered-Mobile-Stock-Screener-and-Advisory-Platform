  import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class AuthUser {
  final int backendUserId;
  final String name;
  final String email;
  final String avatarLabel;
  final String authProvider;
  final bool emailVerified;

  const AuthUser({
    required this.backendUserId,
    required this.name,
    required this.email,
    required this.avatarLabel,
    required this.authProvider,
    required this.emailVerified,
  });

  Map<String, dynamic> toJson() {
    return {
      'backendUserId': backendUserId,
      'name': name,
      'email': email,
      'avatarLabel': avatarLabel,
      'authProvider': authProvider,
      'emailVerified': emailVerified,
    };
  }

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      backendUserId:
          ((json['backendUserId'] ?? json['id']) as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      avatarLabel: (json['avatarLabel'] ?? 'EQ').toString(),
      authProvider: (json['authProvider'] ?? 'password').toString(),
      emailVerified: json['emailVerified'] == true,
    );
  }
}

class AuthResult {
  final bool success;
  final String message;
  final String? devOtp;

  const AuthResult({
    required this.success,
    required this.message,
    this.devOtp,
  });
}

class AuthService extends ChangeNotifier {
  AuthService._();

  static final AuthService instance = AuthService._();

  static const _userKey = 'equiscan_auth_user_v2';
  static const _tokenKey = 'equiscan_auth_token_v2';
  // PASTE YOUR GOOGLE OAUTH CLIENT ID HERE FOR A HARDCODED FALLBACK:
  static const _hardcodedGoogleClientId = '422876120349-gme1b8ce1vhrkagiaakpu8nj8qkqoufp.apps.googleusercontent.com';

  static const _googleClientIdFromBuild = String.fromEnvironment(
    'GOOGLE_OAUTH_CLIENT_ID',
    defaultValue: '',
  );
  static final _googleClientId = _googleClientIdFromBuild.trim().isEmpty
      ? _hardcodedGoogleClientId
      : _googleClientIdFromBuild.trim();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  GoogleSignIn _buildGoogleSignIn() {
    return kIsWeb
        ? GoogleSignIn(
            clientId: _googleClientId,
            scopes: const ['email'],
          )
        : GoogleSignIn(
            serverClientId: _googleClientId,
            scopes: const ['email'],
          );
  }

  AuthUser? _currentUser;
  String? _sessionToken;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _currentUser != null && _sessionToken != null;
  AuthUser? get currentUser => _currentUser;
  int? get currentUserId => _currentUser?.backendUserId;
  String? get sessionToken => _sessionToken;

  static const List<String> avatarOptions = [
    'EQ',
    'AI',
    'TR',
    'MX',
    'QT',
    'IN',
  ];

  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    _sessionToken = await _secureStorage.read(key: _tokenKey);
    final rawUser = prefs.getString(_userKey);
    if (rawUser != null && rawUser.trim().isNotEmpty) {
      final parsed = jsonDecode(rawUser);
      if (parsed is Map<String, dynamic>) {
        _currentUser = AuthUser.fromJson(parsed);
      }
    }

    if (_sessionToken == null || _currentUser == null) {
      await _secureStorage.delete(key: _tokenKey);
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
      _sessionToken = null;
      _currentUser = null;
    }

    _isInitialized = true;
    notifyListeners();
  }

  Map<String, String> authorizedHeaders({
    bool jsonContent = true,
  }) {
    return {
      if (jsonContent) 'Content-Type': 'application/json',
      if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
    };
  }

  Future<AuthResult> requestRegistrationOtp({required String email}) async {
    await initialize();
    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      return const AuthResult(
        success: false,
        message: 'Enter a valid email address.',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': normalizedEmail, 'purpose': 'register'}),
      );
      final body = _decodeMap(response.body);
      if (response.statusCode != 200 || body['success'] != true) {
        return AuthResult(
          success: false,
          message: _extractError(body, 'Unable to send verification code.'),
        );
      }

      return AuthResult(
        success: true,
        message: 'Verification code sent.',
        devOtp: body['devOtp']?.toString(),
      );
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Unable to reach authentication server.',
      );
    }
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    await initialize();

    final normalizedEmail = email.trim().toLowerCase();
    if (!_isValidEmail(normalizedEmail)) {
      return const AuthResult(
        success: false,
        message: 'Enter a valid email address.',
      );
    }

    if (password.isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Enter your password.',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': normalizedEmail, 'password': password}),
      );

      return _consumeAuthResponse(response);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Unable to reach authentication server.',
      );
    }
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String otp,
    required String avatarLabel,
  }) async {
    await initialize();

    final cleanName = name.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (cleanName.length < 2) {
      return const AuthResult(
        success: false,
        message: 'Name must be at least 2 characters.',
      );
    }

    if (!_isValidEmail(normalizedEmail)) {
      return const AuthResult(
        success: false,
        message: 'Enter a valid email address.',
      );
    }

    if (!_isStrongPassword(password)) {
      return const AuthResult(
        success: false,
        message:
            'Use 8+ characters with uppercase, lowercase, number, and symbol.',
      );
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp.trim())) {
      return const AuthResult(
        success: false,
        message: 'Enter the 6 digit verification code.',
      );
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': cleanName,
          'email': normalizedEmail,
          'password': password,
          'otp': otp.trim(),
        }),
      );

      return _consumeAuthResponse(response, avatarLabel: avatarLabel);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Unable to reach authentication server.',
      );
    }
  }

  Future<AuthResult> loginWithGoogle() async {
    await initialize();
    if (_googleClientId.trim().isEmpty) {
      return const AuthResult(
        success: false,
        message: 'Google OAuth client ID is not configured for this build.',
      );
    }

    try {
      final account = await _buildGoogleSignIn().signIn();
      if (account == null) {
        return const AuthResult(success: false, message: 'Google sign-in cancelled.');
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        return const AuthResult(
          success: false,
          message: 'Google did not return an ID token.',
        );
      }

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/users/google'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      return _consumeAuthResponse(response);
    } catch (_) {
      return const AuthResult(
        success: false,
        message: 'Google sign-in is not configured for this platform yet.',
      );
    }
  }

  Future<void> logout() async {
    await initialize();
    _currentUser = null;
    _sessionToken = null;
    try {
      await _buildGoogleSignIn().signOut();
    } catch (_) {
      // Platform Google configuration is optional; local logout should still work.
    }
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.delete(key: _tokenKey);
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    notifyListeners();
  }

  Future<AuthResult> _consumeAuthResponse(
    http.Response response, {
    String? avatarLabel,
  }) async {
    final body = _decodeMap(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        body['success'] != true) {
      return AuthResult(
        success: false,
        message: _extractError(body, 'Authentication failed.'),
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      return const AuthResult(
        success: false,
        message: 'Authentication response was incomplete.',
      );
    }

    final token = data['token']?.toString();
    final userPayload = data['user'];
    if (token == null || token.isEmpty || userPayload is! Map<String, dynamic>) {
      return const AuthResult(
        success: false,
        message: 'Authentication response was incomplete.',
      );
    }

    final selectedAvatar = avatarOptions.contains(avatarLabel)
        ? avatarLabel!
        : avatarOptions.first;
    final user = AuthUser.fromJson({
      ...userPayload,
      'avatarLabel': selectedAvatar,
    });

    _sessionToken = token;
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await _secureStorage.write(key: _tokenKey, value: token);
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
    notifyListeners();

    return const AuthResult(success: true, message: 'Login successful.');
  }

  Map<String, dynamic> _decodeMap(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  String _extractError(Map<String, dynamic> body, String fallback) {
    if (body['error'] is String) return body['error'].toString();
    if (body['message'] is String) return body['message'].toString();
    if (body['errors'] is List && (body['errors'] as List).isNotEmpty) {
      final first = (body['errors'] as List).first;
      if (first is Map && first['msg'] != null) return first['msg'].toString();
    }
    return fallback;
  }

  bool _isValidEmail(String value) {
    final expression = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return expression.hasMatch(value);
  }

  bool _isStrongPassword(String value) {
    return value.length >= 8 &&
        RegExp(r'[a-z]').hasMatch(value) &&
        RegExp(r'[A-Z]').hasMatch(value) &&
        RegExp(r'\d').hasMatch(value) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(value);
  }
}
