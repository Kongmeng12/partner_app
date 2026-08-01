import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The three operations TokenStore needs from a secure store.
///
/// TokenStore depends on this rather than on FlutterSecureStorage directly:
/// the plugin's option classes change shape between major versions, and a test
/// should not have to track that just to keep two strings in memory.
abstract class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  const FlutterSecureKeyValueStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// An in-memory store, for tests.
class InMemoryKeyValueStore implements SecureKeyValueStore {
  InMemoryKeyValueStore([Map<String, String>? seed]) : _data = {...?seed};

  final Map<String, String> _data;

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async => _data[key] = value;

  @override
  Future<void> delete(String key) async => _data.remove(key);
}

/// Where the access and refresh tokens live between launches.
///
/// Secure storage rather than SharedPreferences: the refresh token is good for
/// seven days and grants full access to the partner's bookings, guests and bank
/// details. On Android the plugin encrypts with keystore-backed ciphers by
/// default — the old `encryptedSharedPreferences` flag is deprecated and does
/// nothing, so it is deliberately not passed.
class TokenStore {
  TokenStore({SecureKeyValueStore? storage})
      : _storage = storage ?? const FlutterSecureKeyValueStore();

  final SecureKeyValueStore _storage;

  static const accessKey = 'laostay.partner.accessToken';
  static const refreshKey = 'laostay.partner.refreshToken';

  /// Cached in memory so the request interceptor does not hit the keystore on
  /// every call — a list screen fires several requests at once.
  String? _access;
  String? _refresh;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _access = await _storage.read(accessKey);
    _refresh = await _storage.read(refreshKey);
    _loaded = true;
  }

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get hasSession => _refresh != null && _refresh!.isNotEmpty;

  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
    _loaded = true;
    await _storage.write(accessKey, access);
    await _storage.write(refreshKey, refresh);
  }

  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _loaded = true;
    await _storage.delete(accessKey);
    await _storage.delete(refreshKey);
  }
}
