import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstract storage interface for securely storing sensitive credentials (e.g., API keys).
abstract class SecureKeyStore {
  /// Reads a decrypted value for the given [key].
  Future<String?> read(String key);

  /// Securely encrypts and stores the given [value] for [key].
  Future<void> write(String key, String value);

  /// Removes the stored credential for [key].
  Future<void> delete(String key);
}

/// Production implementation of [SecureKeyStore] backed by [FlutterSecureStorage].
///
/// Uses platform-native secure enclaves/credential stores:
/// - macOS / iOS: Keychain
/// - Android: EncryptedSharedPreferences / Android Keystore
/// - Windows: Windows Credential Manager
/// - Linux: libsecret
class FlutterSecureKeyStore implements SecureKeyStore {
  final FlutterSecureStorage _storage;

  /// Creates a [FlutterSecureKeyStore] instance with optional custom storage options.
  FlutterSecureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory implementation of [SecureKeyStore] suitable for unit and widget testing.
class InMemoryKeyStore implements SecureKeyStore {
  final Map<String, String> _store;

  /// Creates an [InMemoryKeyStore], optionally seeded with [initialData].
  InMemoryKeyStore([Map<String, String>? initialData])
    : _store = initialData != null ? Map<String, String>.from(initialData) : {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}
