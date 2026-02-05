import 'package:flutter/foundation.dart';
import '../models/service.dart';
import '../services/ssh_service.dart';

class ServiceProvider with ChangeNotifier {
  final SshService _sshService;

  List<Service> _services = [];
  bool _isLoading = false;
  String? _error;

  ServiceProvider(this._sshService);

  List<Service> get services => _services;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadServices() async {
    if (!_sshService.isConnected) {
      _error = 'Не подключено к устройству';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _services = await _sshService.getServices();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка загрузки служб: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startService(String serviceName) async {
    try {
      final result = await _sshService.startService(serviceName);
      if (result) {
        await loadServices();
      }
      return result;
    } catch (e) {
      _error = 'Ошибка запуска службы: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> stopService(String serviceName) async {
    try {
      final result = await _sshService.stopService(serviceName);
      if (result) {
        await loadServices();
      }
      return result;
    } catch (e) {
      _error = 'Ошибка остановки службы: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restartService(String serviceName) async {
    try {
      final result = await _sshService.restartService(serviceName);
      if (result) {
        await loadServices();
      }
      return result;
    } catch (e) {
      _error = 'Ошибка перезапуска службы: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> enableService(String serviceName) async {
    try {
      final result = await _sshService.enableService(serviceName);
      if (result) {
        await loadServices();
      }
      return result;
    } catch (e) {
      _error = 'Ошибка включения службы: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> disableService(String serviceName) async {
    try {
      final result = await _sshService.disableService(serviceName);
      if (result) {
        await loadServices();
      }
      return result;
    } catch (e) {
      _error = 'Ошибка отключения службы: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
