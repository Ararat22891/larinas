import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/linux_device.dart';
import 'secure_storage_service.dart';

class DeviceStorageService {
  static const String _devicesKey = 'linux_devices';
  final SecureStorageService _secureStorage = SecureStorageService();

  Future<List<LinuxDevice>> getDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = prefs.getStringList(_devicesKey) ?? [];

    final devices = devicesJson
        .map((json) => LinuxDevice.fromJson(jsonDecode(json)))
        .toList();

    bool migrated = false;
    final updated = <LinuxDevice>[];

    for (final device in devices) {
      try {
        if ((device.password ?? '').isNotEmpty) {
          await _secureStorage.savePassword(device.id, device.password!);
          migrated = true;
          updated.add(device.copyWith(password: null, rememberCredentials: true));
          continue;
        }

        final stored = await _secureStorage.readPassword(device.id);
        if (stored != null && stored.isNotEmpty) {
          updated.add(device.copyWith(password: stored, rememberCredentials: true));
        } else {
          updated.add(device);
        }
      } catch (_) {
        // Если secure storage недоступен, не ломаем список устройств
        updated.add(device.copyWith(password: null));
      }
    }

    if (migrated) {
      await _saveDevices(updated.map((d) => d.copyWith(password: null)).toList());
    }

    return updated;
  }

  Future<void> saveDevice(LinuxDevice device) async {
    final devices = await getDevices();
    final existingIndex = devices.indexWhere((d) => d.id == device.id);

    try {
      if (device.rememberCredentials && (device.password ?? '').isNotEmpty) {
        await _secureStorage.savePassword(device.id, device.password!);
      } else {
        await _secureStorage.deletePassword(device.id);
      }
    } catch (_) {
      // ignore secure storage issues; still save device metadata
    }
    
    if (existingIndex >= 0) {
      devices[existingIndex] = device.copyWith(password: null);
    } else {
      devices.add(device.copyWith(password: null));
    }

    await _saveDevices(devices);
  }

  Future<void> deleteDevice(String deviceId) async {
    final devices = await getDevices();
    devices.removeWhere((d) => d.id == deviceId);
    try {
      await _secureStorage.deletePassword(deviceId);
    } catch (_) {
      // ignore
    }
    await _saveDevices(devices);
  }

  Future<void> _saveDevices(List<LinuxDevice> devices) async {
    final prefs = await SharedPreferences.getInstance();
    final devicesJson = devices
        .map((device) => jsonEncode(device.toJson()))
        .toList();
    await prefs.setStringList(_devicesKey, devicesJson);
  }
}
