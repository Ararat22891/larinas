import 'dart:async';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  List<_LogTemplate> _templates = [];
  final Set<String> _selectedTemplateIds = {};

  @override
  void dispose() {
    _pathController.dispose();
    _archiveInnerPathController.dispose();
    _dateFormatController.dispose();
    _dateExtractController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadTemplates();
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1100;
          if (isWide) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            children: [
                              _buildConfigPanel(context),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildActions(context, devices),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: _buildDevicePanel(context, groupNames, groups),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _buildConfigPanel(context),
                const SizedBox(height: 12),
                _buildDevicePanel(context, groupNames, groups),
                const SizedBox(height: 12),
                _buildActions(context, devices),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDevicePanel(
    BuildContext context,
    List<String> groupNames,
    Map<String, List<LinuxDevice>> groups,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          _buildDevicePanelHeader(context),
          Expanded(
            child: ListView.builder(
              itemCount: groupNames.length,
              itemBuilder: (context, index) {
                final group = groupNames[index];
                final list = groups[group] ?? [];
                return _buildGroupSection(context, group, list);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicePanelHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.dns, size: 16),
          const SizedBox(width: 8),
          const Text('Сервера'),
          const Spacer(),
          TextButton(
            onPressed: _selectAllDevices,
            child: const Text('Выбрать все'),
          ),
          TextButton(
            onPressed: () => setState(() {
              _selectedIds.clear();
              _selectedGroups.clear();
            }),
            child: const Text('Снять выбор'),
          ),
        ],
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
          _buildTemplatePanel(context),
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
          const SizedBox(height: 6),
          Row(
            children: const [
              Icon(Icons.info_outline, size: 16, color: Colors.grey),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Regex должен захватывать дату в первой группе. Пример: ^(.{19}) для строки "2026-02-05 12:34:56".',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _OptionCheck(
                value: _sortByNameDate,
                label: 'Сортировать по названию (дата)',
                onChanged: (value) => setState(() => _sortByNameDate = value ?? true),
              ),
              _OptionCheck(
                value: _sortByTime,
                label: 'Обрезать по времени',
                onChanged: (value) => setState(() => _sortByTime = value ?? true),
              ),
              _OptionCheck(
                value: _includeNoDateLines,
                label: 'Оставлять строки без даты',
                onChanged: (value) => setState(() => _includeNoDateLines = value ?? true),
              ),
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

  Widget _buildTemplatePanel(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              border: Border(
                bottom: BorderSide(color: theme.dividerColor),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.bookmarks_outlined, size: 16),
                const SizedBox(width: 8),
                const Text('Шаблоны логов'),
                const Spacer(),
                OutlinedButton(
                  onPressed: _saveTemplate,
                  child: const Text('Сохранить'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _selectedTemplateIds.isEmpty ? null : _deleteTemplate,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Удалить шаблон',
                ),
              ],
            ),
          ),
          if (_templates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: theme.hintColor),
                  const SizedBox(width: 8),
                  Text(
                    'Шаблонов нет. Сохраните текущие настройки.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: MediaQuery.of(context).size.height < 800 ? 120 : 180,
              child: ListView.builder(
                itemCount: _templates.length,
                itemBuilder: (context, index) {
                  final template = _templates[index];
                  final isSelected = _selectedTemplateIds.contains(template.id);
                  return InkWell(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedTemplateIds.remove(template.id);
                        } else {
                          _selectedTemplateIds.add(template.id);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withValues(alpha: 0.08)
                            : theme.colorScheme.surface,
                        border: Border(
                          bottom: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.hintColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  template.name,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  template.path,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Checkbox(
                            value: isSelected,
                            onChanged: (_) {
                              setState(() {
                                if (isSelected) {
                                  _selectedTemplateIds.remove(template.id);
                                } else {
                                  _selectedTemplateIds.add(template.id);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
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
      final templatesToUse = _selectedTemplateIds.isNotEmpty
          ? _templates.where((t) => _selectedTemplateIds.contains(t.id)).toList()
          : <_LogTemplate>[];
      final hasTemplates = templatesToUse.isNotEmpty;

      final basePath = _pathController.text.trim();
      if (!hasTemplates && basePath.isEmpty) {
        throw Exception('Укажите путь к логам или выберите шаблон');
      }

      for (final device in devices) {
        if (hasTemplates) {
          for (final template in templatesToUse) {
            await _collectForDevice(
              device,
              template.path,
              targetDir,
              template: template,
            );
          }
        } else {
          await _collectForDevice(
            device,
            basePath,
            targetDir,
          );
        }
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
    {_LogTemplate? template}
  ) async {
    final ssh = SshService();
    final connected = await ssh.connect(device);
    if (!connected) {
      throw Exception('Не удалось подключиться к ${device.name}');
    }

    try {
      if (template != null) {
        _applyTemplateToState(template);
      }
      final paths = await _resolvePaths(ssh, pathPattern);
      final logLabel = _resolveLogLabel(pathPattern, templateName: template?.name);
      final hostDir = p.join(targetDir, device.host);
      final logDir = p.join(hostDir, logLabel);
      await Directory(logDir).create(recursive: true);
      for (final remote in paths) {
        await _processRemotePath(
          ssh,
          device,
          remote,
          logDir,
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
    final outputName = p.basename(remoteFile);
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
      final outputName = p.basename(file.name);
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

  void _applyTemplateToState(_LogTemplate template) {
    _archiveInnerPathController.text = template.archiveInnerPath;
    _dateFormatController.text = template.dateFormat;
    _dateExtractController.text = template.dateRegex;
    _sortByNameDate = template.sortByNameDate;
    _sortByTime = template.sortByTime;
    _includeNoDateLines = template.includeNoDateLines;
    _timeFrom = template.timeFrom;
    _timeTo = template.timeTo;
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

  void _selectAllDevices() {
    final provider = context.read<DeviceProvider>();
    setState(() {
      _selectedIds.addAll(provider.devices.map((d) => d.id));
      _selectedGroups
        ..clear()
        ..addAll(_groupDevices(provider.devices).keys);
    });
  }

  String _resolveLogLabel(String pattern, {String? templateName}) {
    if (templateName != null && templateName.trim().isNotEmpty) {
      return templateName.trim();
    }
    var value = pattern.trim();
    if (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (value.contains('/')) {
      value = value.split('/').last;
    }
    value = value.replaceAll('*', '').replaceAll('?', '').trim();
    if (value.isEmpty) return 'logs';
    return value;
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_templateKey) ?? [];
    setState(() {
      _templates = raw.map(_LogTemplate.fromStorage).toList();
      if (_templates.isNotEmpty && _selectedTemplateIds.isEmpty) {
        _selectedTemplateIds.add(_templates.first.id);
      }
    });
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _templateKey,
      _templates.map((t) => t.toStorage()).toList(),
    );
  }

  Future<void> _saveTemplate() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сохранить шаблон'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final template = _LogTemplate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      path: _pathController.text.trim(),
      archiveInnerPath: _archiveInnerPathController.text.trim(),
      dateFormat: _dateFormatController.text.trim(),
      dateRegex: _dateExtractController.text.trim(),
      sortByNameDate: _sortByNameDate,
      sortByTime: _sortByTime,
      includeNoDateLines: _includeNoDateLines,
      timeFrom: _timeFrom,
      timeTo: _timeTo,
    );

    setState(() {
      _templates.add(template);
      _selectedTemplateIds.add(template.id);
    });
    await _saveTemplates();
  }

  Future<void> _deleteTemplate() async {
    if (_selectedTemplateIds.isEmpty) return;
    setState(() {
      _templates.removeWhere((t) => _selectedTemplateIds.contains(t.id));
      _selectedTemplateIds.clear();
    });
    await _saveTemplates();
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

class _OptionCheck extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool?> onChanged;

  const _OptionCheck({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, onChanged: onChanged),
          Flexible(child: Text(label)),
        ],
      ),
    );
  }
}

const _templateKey = 'log_templates';

class _LogTemplate {
  final String id;
  final String name;
  final String path;
  final String archiveInnerPath;
  final String dateFormat;
  final String dateRegex;
  final bool sortByNameDate;
  final bool sortByTime;
  final bool includeNoDateLines;
  final TimeOfDay? timeFrom;
  final TimeOfDay? timeTo;

  const _LogTemplate({
    required this.id,
    required this.name,
    required this.path,
    required this.archiveInnerPath,
    required this.dateFormat,
    required this.dateRegex,
    required this.sortByNameDate,
    required this.sortByTime,
    required this.includeNoDateLines,
    required this.timeFrom,
    required this.timeTo,
  });

  String toStorage() {
    final from = timeFrom == null ? '' : '${timeFrom!.hour}:${timeFrom!.minute}';
    final to = timeTo == null ? '' : '${timeTo!.hour}:${timeTo!.minute}';
    return [
      id,
      name,
      path,
      archiveInnerPath,
      dateFormat,
      dateRegex,
      sortByNameDate ? '1' : '0',
      sortByTime ? '1' : '0',
      includeNoDateLines ? '1' : '0',
      from,
      to,
    ].join('|');
  }

  factory _LogTemplate.fromStorage(String raw) {
    final parts = raw.split('|');
    TimeOfDay? parseTime(String value) {
      if (value.isEmpty || !value.contains(':')) return null;
      final seg = value.split(':');
      return TimeOfDay(
        hour: int.tryParse(seg[0]) ?? 0,
        minute: int.tryParse(seg[1]) ?? 0,
      );
    }

    return _LogTemplate(
      id: parts.isNotEmpty ? parts[0] : DateTime.now().millisecondsSinceEpoch.toString(),
      name: parts.length > 1 ? parts[1] : 'Шаблон',
      path: parts.length > 2 ? parts[2] : '',
      archiveInnerPath: parts.length > 3 ? parts[3] : '',
      dateFormat: parts.length > 4 ? parts[4] : 'yyyy-MM-dd HH:mm:ss',
      dateRegex: parts.length > 5 ? parts[5] : r'^(.{19})',
      sortByNameDate: parts.length > 6 ? parts[6] == '1' : true,
      sortByTime: parts.length > 7 ? parts[7] == '1' : true,
      includeNoDateLines: parts.length > 8 ? parts[8] == '1' : true,
      timeFrom: parts.length > 9 ? parseTime(parts[9]) : null,
      timeTo: parts.length > 10 ? parseTime(parts[10]) : null,
    );
  }
}
