import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  Future<void> savePassword(String deviceId, String password) async {
    await _storage.write(key: _key(deviceId, 'password'), value: password);
  }

  Future<String?> readPassword(String deviceId) async {
    return _storage.read(key: _key(deviceId, 'password'));
  }

  Future<void> deletePassword(String deviceId) async {
    await _storage.delete(key: _key(deviceId, 'password'));
  }

  Future<void> saveSecret(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readSecret(String key) async {
    return _storage.read(key: key);
  }

  Future<void> deleteSecret(String key) async {
    await _storage.delete(key: key);
  }

  String _key(String deviceId, String field) => 'device_${deviceId}_$field';
}
