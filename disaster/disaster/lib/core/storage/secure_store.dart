import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted key-value storage for tokens and other secrets.
///
/// No secrets should ever live in plaintext files or commits.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String keyAccessToken = 'auth.access_token';
  static const String keyRefreshToken = 'auth.refresh_token';
  static const String keyUserId = 'auth.user_id';
  static const String keyDeviceId = 'device.id';

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);

  Future<void> saveTokens({String? accessToken, String? refreshToken}) async {
    if (accessToken != null) await write(keyAccessToken, accessToken);
    if (refreshToken != null) await write(keyRefreshToken, refreshToken);
  }

  Future<void> clearTokens() async {
    await delete(keyAccessToken);
    await delete(keyRefreshToken);
  }
}
