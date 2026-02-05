import 'package:flutter/foundation.dart';
import '../models/file_item.dart';
import '../services/ssh_service.dart';

class FileProvider with ChangeNotifier {
  final SshService _sshService;

  List<FileItem> _files = [];
  String _currentPath = '/';
  bool _isLoading = false;
  String? _error;

  FileProvider(this._sshService);

  List<FileItem> get files => _files;
  String get currentPath => _currentPath;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadFiles(String path) async {
    if (!_sshService.isConnected) {
      _error = 'Не подключено к устройству';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _files = await _sshService.listFiles(path);
      _currentPath = path;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Ошибка загрузки файлов: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> navigateToDirectory(String path) async {
    await loadFiles(path);
  }

  Future<void> navigateUp() async {
    if (_currentPath == '/') return;
    
    final parts = _currentPath.split('/').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      await loadFiles('/');
    } else {
      parts.removeLast();
      final newPath = parts.isEmpty ? '/' : '/${parts.join('/')}';
      await loadFiles(newPath);
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> deletePath(String path) async {
    try {
      await _sshService.deletePath(path);
      await loadFiles(_currentPath);
    } catch (e) {
      _error = 'Ошибка удаления: $e';
      notifyListeners();
    }
  }

  Future<void> createFolder(String name) async {
    try {
      final path = _currentPath.endsWith('/') ? '$_currentPath$name' : '$_currentPath/$name';
      await _sshService.createDirectory(path);
      await loadFiles(_currentPath);
    } catch (e) {
      _error = 'Ошибка создания папки: $e';
      notifyListeners();
    }
  }

  Future<void> createFile(String name) async {
    try {
      final path = _currentPath.endsWith('/') ? '$_currentPath$name' : '$_currentPath/$name';
      await _sshService.createFile(path);
      await loadFiles(_currentPath);
    } catch (e) {
      _error = 'Ошибка создания файла: $e';
      notifyListeners();
    }
  }

  Future<String> readFile(String path) async {
    try {
      return await _sshService.readFile(path);
    } catch (e) {
      _error = 'Ошибка чтения файла: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> writeFile(String path, String content) async {
    try {
      await _sshService.writeFile(path, content);
      await loadFiles(_currentPath);
    } catch (e) {
      _error = 'Ошибка сохранения файла: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> renamePath(String oldPath, String newName) async {
    try {
      final parent = oldPath.split('/')..removeLast();
      final base = parent.isEmpty ? '' : parent.join('/');
      final newPath = base.isEmpty ? '/$newName' : '$base/$newName';
      await _sshService.renamePath(oldPath, newPath);
      await loadFiles(_currentPath);
    } catch (e) {
      _error = 'Ошибка переименования: $e';
      notifyListeners();
    }
  }

  Future<void> duplicatePath(String sourcePath, String newName) async {
    try {
      final parent = sourcePath.split('/')..removeLast();
      final base = parent.isEmpty ? '' : parent.join('/');
      final destination = base.isEmpty ? '/$newName' : '$base/$newName';
      await _sshService.copyPath(sourcePath, destination);
      await loadFiles(_currentPath);
    } catch (e) {
      _error = 'Ошибка копирования: $e';
      notifyListeners();
    }
  }

  Future<void> chmodPath(String path, String mode) async {
    try {
      await _sshService.chmodPath(path, mode);
      await loadFiles(_currentPath);
    } catch (e) {
      _error = 'Ошибка изменения прав: $e';
      notifyListeners();
    }
  }
}
