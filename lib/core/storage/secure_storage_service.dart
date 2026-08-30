import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token vault backed by Keystore (Android) / Keychain (iOS).
class SecureStorageService {
  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              // v11 defaults already wrap the keys with AES-GCM + RSA-OAEP.
              aOptions: AndroidOptions(),
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock),
            );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'xirfadle.access_token';
  static const _refreshTokenKey = 'xirfadle.refresh_token';

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

/// Non-sensitive app preferences.
class AppPreferences {
  AppPreferences(this._prefs);

  final SharedPreferences _prefs;

  static const _activeRoleKey = 'xirfadle.active_role';
  static const _lastPhoneKey = 'xirfadle.last_phone';

  String? get activeRole => _prefs.getString(_activeRoleKey);
  Future<void> setActiveRole(String? role) async {
    if (role == null) {
      await _prefs.remove(_activeRoleKey);
    } else {
      await _prefs.setString(_activeRoleKey, role);
    }
  }

  String? get lastPhone => _prefs.getString(_lastPhoneKey);
  Future<void> setLastPhone(String phone) =>
      _prefs.setString(_lastPhoneKey, phone);
}

final secureStorageProvider =
    Provider<SecureStorageService>((ref) => SecureStorageService());

/// Overridden in `main()` with the resolved instance so the rest of the app
/// can read preferences synchronously.
final appPreferencesProvider = Provider<AppPreferences>(
  (ref) => throw UnimplementedError('appPreferencesProvider was not overridden'),
);
