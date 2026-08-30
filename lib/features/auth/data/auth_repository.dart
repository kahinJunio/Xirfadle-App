import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

import '../../../app/config/api_config.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/json_utils.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage_service.dart';

/// Tokens plus the principal decoded from them.
class AuthSession {
  const AuthSession({required this.user, required this.accessToken});

  final AppUser user;
  final String accessToken;
}

class AuthRepository {
  AuthRepository(this._api, this._storage);

  final ApiClient _api;
  final SecureStorageService _storage;

  Future<AuthSession> login({
    required String phoneNumber,
    required String password,
  }) =>
      _authenticate(ApiConfig.login, {
        'phoneNumber': phoneNumber,
        'password': password,
      });

  Future<AuthSession> register({
    required String fullName,
    required String phoneNumber,
    required String password,
    required String role,
    String? categoryId,
  }) =>
      _authenticate(ApiConfig.register, {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        'password': password,
        'role': role,
        'categoryId': ?categoryId,
      });

  Future<AuthSession> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.post<dynamic>(path, data: body);
    final json = asObject(response);

    final accessToken =
        asStringOrNull(json, ['accessToken', 'token', 'jwt', 'access_token']);
    if (accessToken == null) {
      throw const ApiException('The server did not return a sign-in token.');
    }

    await _storage.saveTokens(
      accessToken: accessToken,
      refreshToken: asStringOrNull(json, ['refreshToken', 'refresh_token']),
    );

    var user = _userFromToken(accessToken);
    // Registration/login responses often embed the profile; prefer it.
    final embedded = pick(json, ['user', 'profile']);
    if (embedded is Map) {
      user = user.mergeProfile(embedded.cast<String, dynamic>());
    }
    return AuthSession(user: user, accessToken: accessToken);
  }

  /// Restores a session from disk on cold start. Returns null when there is no
  /// usable token.
  Future<AuthSession?> restoreSession() async {
    final token = await _storage.readAccessToken();
    if (token == null || token.isEmpty) return null;

    if (_isExpired(token)) {
      // Let the interceptor try a refresh on the first real call; if there is
      // no refresh token there is nothing to restore.
      final refresh = await _storage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        await _storage.clear();
        return null;
      }
    }

    return AuthSession(user: _userFromToken(token), accessToken: token);
  }

  /// Best-effort profile top-up; failures leave the claim-derived user intact.
  Future<AppUser> fetchProfile(AppUser current) async {
    try {
      final response = await _api.get<dynamic>(ApiConfig.me);
      return current.mergeProfile(asObject(response));
    } on ApiException {
      return current;
    }
  }

  Future<void> signOut() => _storage.clear();

  AppUser _userFromToken(String token) {
    try {
      return AppUser.fromClaims(JwtDecoder.decode(token));
    } catch (_) {
      throw const ApiException('The sign-in token could not be read.');
    }
  }

  bool _isExpired(String token) {
    try {
      return JwtDecoder.isExpired(token);
    } catch (_) {
      return true;
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(secureStorageProvider),
  ),
);
