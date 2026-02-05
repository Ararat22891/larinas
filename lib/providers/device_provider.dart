import 'package:flutter/foundation.dart';
import '../models/linux_device.dart';
import '../models/system_stats.dart';
import '../services/ssh_service.dart';
import '../services/device_storage_service.dart';

class DeviceProvider with ChangeNotifier {
  final SshService _sshService = SshService();
  final DeviceStorageService _storageService = DeviceStorageService();

  List<LinuxDevice> _devices = [];
  LinuxDevice? _selectedDevice;
  SystemStats? _systemStats;
  bool _isLoading = false;
  String? _error;
  Duration? _lastConnectDuration;

  List<LinuxDevice> get devices => _devices;
  LinuxDevice? get selectedDevice => _selectedDevice;
  SystemStats? get systemStats => _systemStats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isConnected => _sshService.isConnected;
  Duration? get lastConnectDuration => _lastConnectDuration;
  void selectDevice(LinuxDevice? device) {
    _selectedDevice = device;
    notifyListeners();
  }

  DeviceProvider() {
    loadDevices();
  }

  Future<void> loadDevices() async {
    try {
      _devices = await _storageService.getDevices();
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка загрузки устройств: $e';
      notifyListeners();
    }
  }

  Future<void> addDevice(LinuxDevice device) async {
    try {
      await _storageService.saveDevice(device);
      await loadDevices();
    } catch (e) {
      _error = 'Ошибка добавления устройства: $e';
      notifyListeners();
    }
  }

  Future<void> updateDevice(LinuxDevice device) async {
    try {
      await _storageService.saveDevice(device);
      await loadDevices();
      if (_selectedDevice?.id == device.id) {
        _selectedDevice = device;
      }
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка обновления устройства: $e';
      notifyListeners();
    }
  }

  Future<void> deleteDevice(String deviceId) async {
    try {
      await _storageService.deleteDevice(deviceId);
      await loadDevices();
      if (_selectedDevice?.id == deviceId) {
        _selectedDevice = null;
        await disconnect();
      }
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка удаления устройства: $e';
      notifyListeners();
    }
  }

  Future<bool> connectToDevice(LinuxDevice device) async {
    _isLoading = true;
    _error = null;
    _lastConnectDuration = null;
    notifyListeners();

    try {
      final stopwatch = Stopwatch()..start();
      final connected = await _sshService.connect(device).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Таймаут подключения. Проверьте доступность устройства.');
        },
      );
      stopwatch.stop();
      _lastConnectDuration = stopwatch.elapsed;
      
      if (connected) {
        if (_selectedDevice != null && _selectedDevice!.id != device.id) {
          final previous = _selectedDevice!.copyWith(isConnected: false);
          await updateDevice(previous);
        }
        _selectedDevice = device.copyWith(
          isConnected: true,
          lastSeen: DateTime.now(),
        );
        await updateDevice(_selectedDevice!);
        await refreshSystemStats();
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Не удалось подключиться к устройству. Проверьте данные подключения.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      if (_selectedDevice != null &&
          _selectedDevice!.id == device.id &&
          _sshService.isConnected) {
        _error = null;
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _lastConnectDuration = null;
      String errorMessage = 'Ошибка подключения: ';
      if (e.toString().contains('timeout') || e.toString().contains('Таймаут')) {
        errorMessage = 'Таймаут подключения. Устройство недоступно или неверный адрес.';
      } else if (e.toString().contains('authentication') || e.toString().contains('password')) {
        errorMessage = 'Ошибка аутентификации. Проверьте логин и пароль.';
      } else if (e.toString().contains('refused') || e.toString().contains('Connection refused')) {
        errorMessage = 'Соединение отклонено. Проверьте порт и доступность SSH сервера.';
      } else {
        errorMessage += e.toString().replaceAll('Exception: ', '');
      }
      
      _error = errorMessage;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _sshService.disconnect();
    if (_selectedDevice != null) {
      _selectedDevice = _selectedDevice?.copyWith(isConnected: false);
      await updateDevice(_selectedDevice!);
    }
    _systemStats = null;
    notifyListeners();
  }

  Future<void> refreshSystemStats() async {
    if (!_sshService.isConnected) return;

    try {
      _systemStats = await _sshService.getSystemStats();
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка получения статистики: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  SshService get sshService => _sshService;
}
