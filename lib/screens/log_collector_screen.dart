import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';

import '../providers/device_provider.dart';
import '../models/linux_device.dart';
import '../services/ssh_service.dart';

class LogCollectorScreen extends StatefulWidget {
  const LogCollectorScreen({super.key});

  @override
  State<LogCollectorScreen> createState() => _LogCollectorScreenState();
}

class _LogCollectorScreenState extends State<LogCollectorScreen> {
  final TextEditingController _pathController = TextEditingController();
  final TextEditingController _archiveInnerPathController = TextEditingController();
  final TextEditingController _dateFormatController =
      TextEditingController(text: 'yyyy-MM-dd HH:mm:ss');
  final TextEditingController _dateExtractController =
      TextEditingController(text: r'^(.{19})');

  bool _sortByNameDate = true;
  bool _sortByTime = true;
  bool _includeNoDateLines = true;
  bool _isLoading = false;

  TimeOfDay? _timeFrom;
  TimeOfDay? _timeTo;

  final Set<String> _selectedIds = {};
  final Set<String> _selectedGroups = {};

  @override
  void dispose() {
    _pathController.dispose();
    _archiveInnerPathController.dispose();
    _dateFormatController.dispose();
    _dateExtractController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DeviceProvider>();
    final devices = provider.devices;
    final groups = _groupDevices(devices);
    final groupNames = groups.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сбор логов'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildConfigPanel(context),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ListView.builder(
                  itemCount: groupNames.length,
                  itemBuilder: (context, index) {
                    final group = groupNames[index];
                    final list = groups[group] ?? [];
                    return _buildGroupSection(context, group, list);
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildActions(context, devices),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Параметры сбора',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pathController,
            decoration: const InputDecoration(
              labelText: 'Путь к логам (поддержка *)',
              hintText: '/var/log/*.log или /var/log/nginx/',
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _archiveInnerPathController,
            decoration: const InputDecoration(
              labelText: 'Путь внутри архива (если файл архив)',
              hintText: 'например logs/app/*.log',
            ),
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateFormatController,
                  decoration: const InputDecoration(
                    labelText: 'Формат даты',
                    hintText: 'yyyy-MM-dd HH:mm:ss',
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _dateExtractController,
                  decoration: const InputDecoration(
                    labelText: 'Regex для даты',
                    hintText: r'^(.{19})',
                  ),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _sortByNameDate,
                onChanged: (value) => setState(() => _sortByNameDate = value ?? true),
              ),
              const Text('Сортировать по названию (дата)'),
              const SizedBox(width: 16),
              Checkbox(
                value: _sortByTime,
                onChanged: (value) => setState(() => _sortByTime = value ?? true),
              ),
              const Text('Обрезать по времени'),
              const SizedBox(width: 16),
              Checkbox(
                value: _includeNoDateLines,
                onChanged: (value) => setState(() => _includeNoDateLines = value ?? true),
              ),
              const Text('Оставлять строки без даты'),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _TimePickerChip(
                label: _timeFrom == null
                    ? 'Время от'
                    : _timeFrom!.format(context),
                onTap: () => _pickTime(context, true),
              ),
              _TimePickerChip(
                label: _timeTo == null
                    ? 'Время до'
                    : _timeTo!.format(context),
                onTap: () => _pickTime(context, false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    String group,
    List<LinuxDevice> devices,
  ) {
    final selectedCount = devices.where((d) => _selectedIds.contains(d.id)).length;
    final allSelected = selectedCount == devices.length && devices.isNotEmpty;
    final someSelected = selectedCount > 0 && !allSelected;

    return Column(
      children: [
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: allSelected ? true : someSelected ? null : false,
                tristate: true,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedIds.addAll(devices.map((d) => d.id));
                      _selectedGroups.add(group);
                    } else {
                      _selectedIds.removeAll(devices.map((d) => d.id));
                      _selectedGroups.remove(group);
                    }
                  });
                },
              ),
              Text(group),
              const SizedBox(width: 6),
              Text('(${devices.length})'),
            ],
          ),
        ),
        for (final device in devices) _buildDeviceRow(context, device),
      ],
    );
  }

  Widget _buildDeviceRow(BuildContext context, LinuxDevice device) {
    final selected = _selectedIds.contains(device.id);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            if (selected) {
              _selectedIds.remove(device.id);
            } else {
              _selectedIds.add(device.id);
            }
          });
        },
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedIds.add(device.id);
                  } else {
                    _selectedIds.remove(device.id);
                  }
                });
              },
            ),
            Expanded(
              child: Text(device.name),
            ),
            Expanded(
              child: Text(
                '${device.username}@${device.host}',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, List<LinuxDevice> devices) {
    final selected = devices.where((d) => _selectedIds.contains(d.id)).toList();
    return Row(
      children: [
        Text('Выбрано машин: ${selected.length}'),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _isLoading || selected.isEmpty ? null : () => _collectLogs(selected),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download),
          label: const Text('Собрать логи'),
        ),
      ],
    );
  }

  Future<void> _collectLogs(List<LinuxDevice> devices) async {
    final targetDir = await FilePicker.platform.getDirectoryPath();
    if (targetDir == null) return;

    setState(() => _isLoading = true);

    try {
      final pathPattern = _pathController.text.trim();
      if (pathPattern.isEmpty) {
        throw Exception('Укажите путь к логам');
      }

      for (final device in devices) {
        await _collectForDevice(device, pathPattern, targetDir);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сбор логов завершен')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _collectForDevice(
    LinuxDevice device,
    String pathPattern,
    String targetDir,
  ) async {
    final ssh = SshService();
    final connected = await ssh.connect(device);
    if (!connected) {
      throw Exception('Не удалось подключиться к ${device.name}');
    }

    try {
      final paths = await _resolvePaths(ssh, pathPattern);
      for (final remote in paths) {
        await _processRemotePath(
          ssh,
          device,
          remote,
          targetDir,
        );
      }
    } finally {
      await ssh.disconnect();
    }
  }

  Future<List<String>> _resolvePaths(SshService ssh, String pattern) async {
    if (pattern.contains('*') || pattern.contains('?')) {
      return ssh.listMatchingPaths(pattern);
    }
    return [pattern];
  }

  Future<void> _processRemotePath(
    SshService ssh,
    LinuxDevice device,
    String remotePath,
    String targetDir,
  ) async {
    final lower = remotePath.toLowerCase();
    if (lower.endsWith('.zip') || lower.endsWith('.tar.gz') || lower.endsWith('.gz')) {
      await _processArchive(ssh, device, remotePath, targetDir);
      return;
    }

    if (remotePath.endsWith('/')) {
      await _processDirectory(ssh, device, remotePath, targetDir);
      return;
    }

    await _downloadAndFilterFile(ssh, device, remotePath, targetDir);
  }

  Future<void> _processDirectory(
    SshService ssh,
    LinuxDevice device,
    String dirPath,
    String targetDir,
  ) async {
    final pattern = dirPath.endsWith('/') ? '$dirPath*' : '$dirPath/*';
    final children = await ssh.listMatchingPaths(pattern);

    if (_sortByNameDate) {
      children.sort((a, b) => a.compareTo(b));
    }

    for (final child in children) {
      await _processRemotePath(ssh, device, child, targetDir);
    }
  }

  Future<void> _downloadAndFilterFile(
    SshService ssh,
    LinuxDevice device,
    String remoteFile,
    String targetDir,
  ) async {
    final tempDir = await Directory.systemTemp.createTemp('logs');
    final localPath = p.join(tempDir.path, p.basename(remoteFile));
    await ssh.downloadFile(remoteFile, localPath);

    final filtered = await _filterLogFile(localPath);
      final outputName = '${device.name}_${p.basename(remoteFile)}';
      final outputPath = p.join(targetDir, outputName);
      await File(outputPath).writeAsString(filtered);
  }

  Future<void> _processArchive(
    SshService ssh,
    LinuxDevice device,
    String remoteArchive,
    String targetDir,
  ) async {
    final tempDir = await Directory.systemTemp.createTemp('logs');
    final localArchive = p.join(tempDir.path, p.basename(remoteArchive));
    await ssh.downloadFile(remoteArchive, localArchive);

    final bytes = await File(localArchive).readAsBytes();
    Archive archive;
    if (remoteArchive.endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
    } else if (remoteArchive.endsWith('.tar.gz') || remoteArchive.endsWith('.gz')) {
      archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    } else {
      return;
    }

    final innerPattern = _archiveInnerPathController.text.trim();
    final files = archive.files.where((f) => f.isFile).toList();

    for (final file in files) {
      if (innerPattern.isNotEmpty && !_matchPath(file.name, innerPattern)) {
        continue;
      }
      final content = file.content as List<int>;
      final filtered = _filterLogContent(String.fromCharCodes(content));
      final outputName = '${device.name}_${p.basename(file.name)}';
      final outputPath = p.join(targetDir, outputName);
      await File(outputPath).writeAsString(filtered);
    }
  }

  bool _matchPath(String path, String pattern) {
    final regex = RegExp(
      '^${RegExp.escape(pattern).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$',
    );
    return regex.hasMatch(path);
  }

  Future<String> _filterLogFile(String localPath) async {
    final content = await File(localPath).readAsString();
    return _filterLogContent(content);
  }

  String _filterLogContent(String content) {
    if (!_sortByTime) return content;

    final format = DateFormat(_dateFormatController.text.trim());
    final regex = RegExp(_dateExtractController.text.trim());
    final buffer = StringBuffer();

    for (final line in content.split('\n')) {
      final match = regex.firstMatch(line);
      if (match == null) {
        if (_includeNoDateLines) buffer.writeln(line);
        continue;
      }
      final raw = match.group(1) ?? '';
      DateTime? dt;
      try {
        dt = format.parse(raw);
      } catch (_) {
        if (_includeNoDateLines) buffer.writeln(line);
        continue;
      }

    if (_timeFrom != null && _timeTo != null) {
      final start = _timeFrom!.hour * 60 + _timeFrom!.minute;
      final end = _timeTo!.hour * 60 + _timeTo!.minute;
      final current = dt.hour * 60 + dt.minute;
      if (current < start || current > end) continue;
      }

      buffer.writeln(line);
    }

    return buffer.toString();
  }

  Future<void> _pickTime(BuildContext context, bool isFrom) async {
    final initial = isFrom ? _timeFrom ?? const TimeOfDay(hour: 0, minute: 0) : _timeTo ?? const TimeOfDay(hour: 23, minute: 59);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _timeFrom = picked;
      } else {
        _timeTo = picked;
      }
    });
  }

  Map<String, List<LinuxDevice>> _groupDevices(List<LinuxDevice> devices) {
    final map = <String, List<LinuxDevice>>{};
    for (final device in devices) {
      final group = (device.group ?? '').trim().isEmpty ? 'Без группы' : device.group!;
      map.putIfAbsent(group, () => []).add(device);
    }
    return map;
  }
}

class _TimePickerChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimePickerChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.access_time, size: 16),
      label: Text(label),
    );
  }
}
