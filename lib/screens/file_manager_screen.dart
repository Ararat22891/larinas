import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:code_text_field/code_text_field.dart';
import 'package:path/path.dart' as p;
import 'package:highlight/highlight.dart';
import 'package:highlight/languages/bash.dart';
import 'package:highlight/languages/json.dart';
import 'package:highlight/languages/yaml.dart';
import 'package:highlight/languages/xml.dart';
import 'package:highlight/languages/ini.dart';
import 'package:highlight/languages/sql.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/javascript.dart';
import 'package:highlight/languages/dart.dart';
import '../providers/device_provider.dart';
import '../providers/file_provider.dart';
import '../models/file_item.dart';
import '../services/ssh_service.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  FileProvider? _fileProvider;
  SshService? _currentService;
  bool _isEditingPath = false;
  final TextEditingController _pathController = TextEditingController();
  bool _initialPathLoaded = false;
  final Set<String> _selectedPaths = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sshService = context.read<DeviceProvider>().sshService;
    if (_fileProvider == null || _currentService != sshService) {
      _currentService = sshService;
      _fileProvider = FileProvider(sshService);
      _initialPathLoaded = false;
      _loadInitialPath();
    }
  }

  Future<void> _loadInitialPath() async {
    if (_fileProvider == null || _initialPathLoaded) return;
    _initialPathLoaded = true;
    final home = await _currentService?.getHomeDirectory() ?? '/';
    await _fileProvider!.loadFiles(home);
    if (!mounted) return;
    if (_fileProvider!.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fileProvider!.error!)),
      );
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final sshService = deviceProvider.sshService;
    
    if (!sshService.isConnected) {
      return const Center(child: Text('Не подключено к устройству'));
    }

    if (_fileProvider == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ChangeNotifierProvider.value(
      value: _fileProvider!,
      child: Consumer<FileProvider>(
        builder: (context, fileProvider, child) {
          if (fileProvider.isLoading && fileProvider.files.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (fileProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    fileProvider.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      fileProvider.clearError();
                      fileProvider.loadFiles(fileProvider.currentPath);
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              _buildPathBar(context, fileProvider),
              Expanded(
                child: _buildFileList(context, fileProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPathBar(BuildContext context, FileProvider fileProvider) {
    final segments = fileProvider.currentPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList();

    _pathController.text = fileProvider.currentPath;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => fileProvider.navigateUp(),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _isEditingPath
                ? TextField(
                    controller: _pathController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: '/var/www',
                    ),
                    style: const TextStyle(fontFamily: 'monospace'),
                    onSubmitted: (value) async {
                      final target = value.trim();
                      if (target.isEmpty) return;
                      await fileProvider.loadFiles(target);
                      if (!mounted) return;
                      if (fileProvider.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(fileProvider.error!)),
                        );
                      }
                      setState(() => _isEditingPath = false);
                    },
                  )
                : GestureDetector(
                    onTap: () => setState(() => _isEditingPath = true),
                    child: _buildBreadcrumb(context, fileProvider, segments),
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            tooltip: 'Новая папка',
            onPressed: () => _showCreateFolderDialog(context, fileProvider),
          ),
          IconButton(
            icon: const Icon(Icons.note_add_outlined),
            tooltip: 'Новый файл',
            onPressed: () => _showCreateFileDialog(context, fileProvider),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Загрузить файл',
            onPressed: () => _uploadFile(context, fileProvider),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              fileProvider.loadFiles(fileProvider.currentPath);
            },
          ),
          IconButton(
            icon: Icon(_isEditingPath ? Icons.check : Icons.edit),
            tooltip: _isEditingPath ? 'Применить путь' : 'Редактировать путь',
            onPressed: () async {
              if (_isEditingPath) {
                final target = _pathController.text.trim();
                if (target.isEmpty) return;
                await fileProvider.loadFiles(target);
                if (!mounted) return;
                if (fileProvider.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(fileProvider.error!)),
                  );
                }
                setState(() => _isEditingPath = false);
              } else {
                setState(() => _isEditingPath = true);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb(
    BuildContext context,
    FileProvider fileProvider,
    List<String> segments,
  ) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _BreadcrumbChip(
            label: 'root',
            onTap: () => fileProvider.loadFiles('/'),
          ),
          for (var i = 0; i < segments.length; i++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 18, color: theme.hintColor),
            ),
            _BreadcrumbChip(
              label: segments[i],
              onTap: () {
                final path = '/${segments.sublist(0, i + 1).join('/')}';
                fileProvider.loadFiles(path);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFileList(BuildContext context, FileProvider fileProvider) {
    final files = fileProvider.files;
    
    // Sort: directories first, then files
    files.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (files.isEmpty) {
      return const Center(
        child: Text('Папка пуста'),
      );
    }

    return Column(
      children: [
        if (_selectedPaths.isNotEmpty)
          _buildSelectionBar(context, fileProvider),
        _buildHeaderRow(context),
        Expanded(
          child: ListView.builder(
            itemCount: files.length,
            itemBuilder: (context, index) {
              final file = files[index];
              return _buildFileRow(context, fileProvider, file);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Checkbox(
              value: _selectedPaths.isNotEmpty &&
                  _selectedPaths.length == _fileProvider?.files.length,
              tristate: true,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedPaths
                      ..clear()
                      ..addAll(_fileProvider?.files.map((f) => f.path) ?? []);
                  } else {
                    _selectedPaths.clear();
                  }
                });
              },
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              'Имя',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Размер',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Изменен',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Владелец',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'Права',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileRow(
    BuildContext context,
    FileProvider fileProvider,
    FileItem file,
  ) {
    final theme = Theme.of(context);
    final icon = file.isDirectory
        ? Icons.folder
        : (file.isSymlink ? Icons.link : Icons.insert_drive_file);
    final iconColor = file.isDirectory
        ? theme.colorScheme.primary
        : (file.isSymlink ? Colors.orange : theme.hintColor);
    final isSelected = _selectedPaths.contains(file.path);
    final selectionMode = _selectedPaths.isNotEmpty;

    return InkWell(
      onTap: () {
        if (selectionMode) {
          setState(() {
            if (isSelected) {
              _selectedPaths.remove(file.path);
            } else {
              _selectedPaths.add(file.path);
            }
          });
          return;
        }

        if (file.isDirectory) {
          fileProvider.navigateToDirectory(file.path);
        } else {
          _showFileInfo(context, file);
        }
      },
      onLongPress: () {
        if (_selectedPaths.isEmpty) {
          setState(() => _selectedPaths.add(file.path));
        } else {
          _showFileMenu(context, fileProvider, file);
        }
      },
      onSecondaryTapDown: (details) {
        _showContextMenu(context, fileProvider, file, details.globalPosition);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.6)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedPaths.add(file.path);
                    } else {
                      _selectedPaths.remove(file.path);
                    }
                  });
                },
              ),
            ),
            Expanded(
              flex: 5,
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                file.isDirectory ? '-' : file.sizeFormatted,
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                _formatDate(file.modified),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                file.owner ?? '-',
                style: theme.textTheme.bodySmall,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                file.permissions ?? '-',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFileInfo(BuildContext context, FileItem file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(file.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Путь: ${file.path}'),
            const SizedBox(height: 8),
            Text('Тип: ${file.isDirectory ? "Папка" : "Файл"}'),
            if (!file.isDirectory) ...[
              const SizedBox(height: 8),
              Text('Размер: ${file.sizeFormatted}'),
            ],
            if (file.permissions != null) ...[
              const SizedBox(height: 8),
              Text('Права: ${file.permissions}'),
            ],
            if (file.owner != null) ...[
              const SizedBox(height: 8),
              Text('Владелец: ${file.owner}'),
            ],
            if (file.group != null) ...[
              const SizedBox(height: 8),
              Text('Группа: ${file.group}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  void _showFileMenu(
    BuildContext context,
    FileProvider fileProvider,
    FileItem file,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('Информация'),
              onTap: () {
                Navigator.pop(context);
                _showFileInfo(context, file);
              },
            ),
            if (!file.isDirectory)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Редактировать'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog(context, fileProvider, file);
                },
              ),
            if (!file.isDirectory)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('Открыть во внешнем'),
                onTap: () {
                  Navigator.pop(context);
                  _openInExternalEditor(context, file);
                },
              ),
            if (_isImageFile(file.name))
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: const Text('Предпросмотр'),
                onTap: () {
                  Navigator.pop(context);
                  _showImagePreview(context, file);
                },
              ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Права доступа'),
              onTap: () {
                Navigator.pop(context);
                _showPermissionsDialog(context, fileProvider, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать имя'),
              onTap: () async {
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: file.name));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Имя скопировано')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать путь'),
              onTap: () async {
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: file.path));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Путь скопирован')),
                  );
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.drive_file_rename_outline),
              title: const Text('Переименовать'),
              onTap: () {
                Navigator.pop(context);
                _showRenameDialog(context, fileProvider, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all),
              title: const Text('Дублировать'),
              onTap: () {
                Navigator.pop(context);
                _showDuplicateDialog(context, fileProvider, file);
              },
            ),
            if (!file.isDirectory)
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Скачать'),
                onTap: () {
                  Navigator.pop(context);
                  _downloadFile(context, file);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Удалить', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, fileProvider, file);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    FileProvider fileProvider,
    FileItem file,
    Offset position,
  ) async {
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx + 1,
        position.dy + 1,
      ),
      items: [
        const PopupMenuItem(value: 'info', child: Text('Информация')),
        if (!file.isDirectory)
          const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
        if (!file.isDirectory)
          const PopupMenuItem(value: 'open-external', child: Text('Открыть во внешнем')),
        if (!file.isDirectory)
          const PopupMenuItem(value: 'download', child: Text('Скачать')),
        if (_isImageFile(file.name))
          const PopupMenuItem(value: 'preview', child: Text('Предпросмотр')),
        const PopupMenuItem(value: 'chmod', child: Text('Права доступа')),
        const PopupMenuItem(value: 'copy-name', child: Text('Копировать имя')),
        const PopupMenuItem(value: 'copy-path', child: Text('Копировать путь')),
        const PopupMenuItem(value: 'rename', child: Text('Переименовать')),
        const PopupMenuItem(value: 'duplicate', child: Text('Дублировать')),
        const PopupMenuItem(
          value: 'delete',
          child: Text('Удалить', style: TextStyle(color: Colors.red)),
        ),
      ],
    );

    if (!context.mounted) return;

    switch (result) {
      case 'info':
        _showFileInfo(context, file);
        break;
      case 'edit':
        _showEditDialog(context, fileProvider, file);
        break;
      case 'open-external':
        await _openInExternalEditor(context, file);
        break;
      case 'download':
        await _downloadFile(context, file);
        break;
      case 'preview':
        await _showImagePreview(context, file);
        break;
      case 'chmod':
        _showPermissionsDialog(context, fileProvider, file);
        break;
      case 'copy-path':
        await Clipboard.setData(ClipboardData(text: file.path));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Путь скопирован')),
          );
        }
        break;
      case 'copy-name':
        await Clipboard.setData(ClipboardData(text: file.name));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Имя скопировано')),
          );
        }
        break;
      case 'rename':
        _showRenameDialog(context, fileProvider, file);
        break;
      case 'duplicate':
        _showDuplicateDialog(context, fileProvider, file);
        break;
      case 'delete':
        _showDeleteDialog(context, fileProvider, file);
        break;
      default:
        break;
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    FileProvider fileProvider,
    FileItem file,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text('Вы уверены, что хотите удалить ${file.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await fileProvider.deletePath(file.path);
              if (!context.mounted) return;
              if (fileProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(fileProvider.error!)),
                );
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadFile(BuildContext context, FileProvider fileProvider) async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.single;
    final localPath = picked.path;
    if (localPath == null) return;

    final remotePath = fileProvider.currentPath.endsWith('/')
        ? '${fileProvider.currentPath}${picked.name}'
        : '${fileProvider.currentPath}/${picked.name}';

    try {
      final ssh = context.read<DeviceProvider>().sshService;
      await ssh.uploadFile(localPath, remotePath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл загружен')),
        );
      }
      await fileProvider.loadFiles(fileProvider.currentPath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _downloadFile(BuildContext context, FileItem file) async {
    final targetDir = await FilePicker.platform.getDirectoryPath();
    if (targetDir == null) return;

    final localPath = '$targetDir${Platform.pathSeparator}${file.name}';

    try {
      final ssh = context.read<DeviceProvider>().sshService;
      await ssh.downloadFile(file.path, localPath);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл скачан')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка скачивания: $e')),
        );
      }
    }
  }

  Future<void> _openInExternalEditor(BuildContext context, FileItem file) async {
    try {
      final ssh = context.read<DeviceProvider>().sshService;
      final tempDir = await Directory.systemTemp.createTemp('larinas_');
      final localPath = p.join(tempDir.path, file.name);
      await ssh.downloadFile(file.path, localPath);
      await _openLocalFile(localPath);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть файл: $e')),
        );
      }
    }
  }

  Future<void> _openLocalFile(String path) async {
    try {
      final uri = Uri.file(path);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    } catch (_) {}

    try {
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', path], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [path]);
      }
    } catch (_) {}
  }

  Future<void> _downloadSelected(
    BuildContext context,
    List<FileItem> selected,
  ) async {
    final targetDir = await FilePicker.platform.getDirectoryPath();
    if (targetDir == null) return;

    final ssh = context.read<DeviceProvider>().sshService;
    int ok = 0;
    int failed = 0;

    for (final file in selected) {
      if (file.isDirectory) continue;
      final localPath = '$targetDir${Platform.pathSeparator}${file.name}';
      try {
        await ssh.downloadFile(file.path, localPath);
        ok += 1;
      } catch (_) {
        failed += 1;
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Скачано: $ok, ошибок: $failed')),
    );
    setState(() => _selectedPaths.clear());
  }

  Widget _buildSelectionBar(BuildContext context, FileProvider fileProvider) {
    final selected = fileProvider.files
        .where((file) => _selectedPaths.contains(file.path))
        .toList();
    final fileCount = selected.where((f) => !f.isDirectory).length;

    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Text('Выбрано: ${selected.length}'),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: fileCount == 0
                ? null
                : () => _downloadSelected(context, selected),
            icon: const Icon(Icons.download),
            label: const Text('Скачать'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() => _selectedPaths.clear()),
            icon: const Icon(Icons.clear),
            label: const Text('Снять выбор'),
          ),
        ],
      ),
    );
  }

  Mode _languageForFile(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.json')) return json;
    if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return yaml;
    if (lower.endsWith('.xml')) return xml;
    if (lower.endsWith('.ini') || lower.endsWith('.conf')) return ini;
    if (lower.endsWith('.sql')) return sql;
    if (lower.endsWith('.py')) return python;
    if (lower.endsWith('.js') || lower.endsWith('.ts')) return javascript;
    if (lower.endsWith('.dart')) return dart;
    return bash;
  }

  void _showEditDialog(
    BuildContext context,
    FileProvider fileProvider,
    FileItem file,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<String>(
          future: fileProvider.readFile(file.path),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                title: Text('Загрузка...'),
                content: SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError) {
              return AlertDialog(
                title: const Text('Ошибка'),
                content: Text('Не удалось открыть файл: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              );
            }

            final content = snapshot.data ?? '';
            final codeController = CodeController(
              text: content,
              language: _languageForFile(file.name),
            );
            final isDirty = ValueNotifier<bool>(false);
            codeController.addListener(() {
              isDirty.value = codeController.text != content;
            });

            return AlertDialog(
              title: Text('Редактирование: ${file.name}'),
              content: SizedBox(
                width: 900,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            file.path,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).hintColor),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openInExternalEditor(context, file),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Открыть во внешнем'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 420,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      child: Scrollbar(
                        child: CodeField(
                          controller: codeController,
                          textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                          expands: true,
                          maxLines: null,
                          minLines: null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<bool>(
                      valueListenable: isDirty,
                      builder: (context, dirty, child) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            dirty ? 'Есть несохранённые изменения' : 'Изменений нет',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: dirty ? Colors.orange : Theme.of(context).hintColor,
                                ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    try {
                      await fileProvider.writeFile(file.path, codeController.text);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Файл сохранен')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка сохранения: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Сохранить'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await fileProvider.writeFile(file.path, codeController.text);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Файл сохранен')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Ошибка сохранения: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Сохранить и закрыть'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _isImageFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp');
  }

  Future<void> _showImagePreview(BuildContext context, FileItem file) async {
    final ssh = context.read<DeviceProvider>().sshService;
    return showDialog(
      context: context,
      builder: (context) {
        return FutureBuilder<List<int>>(
          future: ssh.readFileBytes(file.path),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AlertDialog(
                title: Text('Загрузка изображения...'),
                content: SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            if (snapshot.hasError || snapshot.data == null) {
              return AlertDialog(
                title: const Text('Ошибка'),
                content: Text('Не удалось загрузить изображение: ${snapshot.error}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              );
            }

            final bytes = Uint8List.fromList(snapshot.data!);
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      file.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Flexible(
                    child: InteractiveViewer(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Закрыть'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCreateFolderDialog(
    BuildContext context,
    FileProvider fileProvider,
  ) {
    final controller = TextEditingController(text: 'Новая папка');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать папку'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Название папки'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await fileProvider.createFolder(name);
              if (!context.mounted) return;
              if (fileProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(fileProvider.error!)),
                );
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showCreateFileDialog(
    BuildContext context,
    FileProvider fileProvider,
  ) {
    final controller = TextEditingController(text: 'new-file.txt');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Создать файл'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Имя файла'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await fileProvider.createFile(name);
              if (!context.mounted) return;
              if (fileProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(fileProvider.error!)),
                );
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    FileProvider fileProvider,
    FileItem file,
  ) {
    final controller = TextEditingController(text: file.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Переименовать'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Новое имя'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty || name == file.name) return;
              Navigator.pop(context);
              await fileProvider.renamePath(file.path, name);
              if (!context.mounted) return;
              if (fileProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(fileProvider.error!)),
                );
              }
            },
            child: const Text('Переименовать'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateDialog(
    BuildContext context,
    FileProvider fileProvider,
    FileItem file,
  ) {
    final suggested = file.isDirectory ? '${file.name}-copy' : '${file.name}.copy';
    final controller = TextEditingController(text: suggested);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Дублировать'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Имя копии'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context);
              await fileProvider.duplicatePath(file.path, name);
              if (!context.mounted) return;
              if (fileProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(fileProvider.error!)),
                );
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showPermissionsDialog(
    BuildContext context,
    FileProvider fileProvider,
    FileItem file,
  ) {
    final current = file.permissions ?? '';
    final controller = TextEditingController(
      text: current.length >= 3 ? current.substring(current.length - 3) : '755',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Права доступа (chmod)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.name,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Режим (например 644 или 755)',
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final mode = controller.text.trim();
              if (mode.isEmpty) return;
              Navigator.pop(context);
              await fileProvider.chmodPath(file.path, mode);
              if (!context.mounted) return;
              if (fileProvider.error != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(fileProvider.error!)),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Права обновлены')),
                );
              }
            },
            child: const Text('Применить'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}

class _BreadcrumbChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _BreadcrumbChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
