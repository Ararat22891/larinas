import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/device_provider.dart';
import '../models/linux_device.dart';
import '../services/ssh_service.dart';

class PlaybookScreen extends StatefulWidget {
  const PlaybookScreen({super.key});

  @override
  State<PlaybookScreen> createState() => _PlaybookScreenState();
}

class _PlaybookScreenState extends State<PlaybookScreen> {
  final List<_Playbook> _playbooks = [];
  bool _loading = false;
  bool _templatesAdded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('playbooks') ?? [];
    _playbooks
      ..clear()
      ..addAll(raw.map((e) => _Playbook.fromJson(jsonDecode(e) as Map<String, dynamic>)));
    if (_playbooks.isEmpty && !_templatesAdded) {
      _playbooks.addAll(_defaultTemplates());
      _templatesAdded = true;
      await _save();
    }
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _playbooks.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList('playbooks', raw);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playbooks'),
        actions: [
          IconButton(
            onPressed: _createPlaybook,
            icon: const Icon(Icons.add),
            tooltip: 'Новый playbook',
          ),
          IconButton(
            onPressed: () async {
              setState(() => _playbooks.addAll(_defaultTemplates()));
              await _save();
            },
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Добавить шаблоны',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: _playbooks.length,
                itemBuilder: (context, index) {
                  final p = _playbooks[index];
                  return Card(
                    child: ListTile(
                      title: Text(p.name),
                      subtitle: Text('Шагов: ${p.steps.length}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _editPlaybook(p),
                            icon: const Icon(Icons.edit),
                          ),
                          IconButton(
                            onPressed: _loading ? null : () => _runPlaybook(p),
                            icon: const Icon(Icons.play_arrow),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => _playbooks.removeAt(index));
                              _save();
                            },
                            icon: const Icon(Icons.delete, color: Colors.red),
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
      ),
    );
  }

  Future<void> _createPlaybook() async {
    final playbook = _Playbook(name: 'Новый playbook', steps: []);
    await _editPlaybook(playbook, isNew: true);
  }

  List<_Playbook> _defaultTemplates() {
    return [
      _Playbook(
        name: 'Обновление системы (APT)',
        steps: [
          _PlaybookStep('Обновить индекс', 'sudo apt update'),
          _PlaybookStep('Обновить пакеты', 'sudo apt -y upgrade'),
        ],
      ),
      _Playbook(
        name: 'Перезапуск Tomcat',
        steps: [
          _PlaybookStep('Остановить', 'sudo systemctl stop tomcat'),
          _PlaybookStep('Запустить', 'sudo systemctl start tomcat'),
          _PlaybookStep('Статус', 'systemctl status tomcat --no-pager'),
        ],
      ),
      _Playbook(
        name: 'Перезапуск ActiveMQ',
        steps: [
          _PlaybookStep('Остановить', 'sudo systemctl stop activemq'),
          _PlaybookStep('Запустить', 'sudo systemctl start activemq'),
          _PlaybookStep('Статус', 'systemctl status activemq --no-pager'),
        ],
      ),
      _Playbook(
        name: 'Ротация логов',
        steps: [
          _PlaybookStep('Проверка logrotate', 'logrotate -d /etc/logrotate.conf'),
          _PlaybookStep('Принудительная ротация', 'logrotate -f /etc/logrotate.conf'),
        ],
      ),
      _Playbook(
        name: 'Проверка места',
        steps: [
          _PlaybookStep('Диски', 'df -h'),
          _PlaybookStep('Inodes', 'df -ih'),
        ],
      ),
    ];
  }

  Future<void> _editPlaybook(_Playbook playbook, {bool isNew = false}) async {
    final nameController = TextEditingController(text: playbook.name);
    final steps = List<_PlaybookStep>.from(playbook.steps);

    final result = await showDialog<_Playbook>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Playbook'),
        content: SizedBox(
          width: 640,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Шаги'),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      steps.add(_PlaybookStep('Новый шаг', 'echo ok'));
                      (context as Element).markNeedsBuild();
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 280,
                child: ListView.builder(
                  itemCount: steps.length,
                  itemBuilder: (context, index) {
                    final step = steps[index];
                    return Card(
                      child: ListTile(
                        title: TextField(
                          controller: TextEditingController(text: step.title),
                          decoration: const InputDecoration(labelText: 'Название шага'),
                          onChanged: (value) => step.title = value,
                        ),
                        subtitle: TextField(
                          controller: TextEditingController(text: step.command),
                          decoration: const InputDecoration(labelText: 'Команда'),
                          onChanged: (value) => step.command = value,
                          style: const TextStyle(fontFamily: 'monospace'),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            steps.removeAt(index);
                            (context as Element).markNeedsBuild();
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, _Playbook(name: name, steps: steps));
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (isNew) {
      setState(() => _playbooks.add(result));
    } else {
      final index = _playbooks.indexOf(playbook);
      if (index >= 0) {
        setState(() => _playbooks[index] = result);
      }
    }
    await _save();
  }

  Future<void> _runPlaybook(_Playbook playbook) async {
    final provider = context.read<DeviceProvider>();
    final devices = provider.devices;
    final selected = await _selectDevices(devices);
    if (selected == null || selected.isEmpty) return;

    setState(() => _loading = true);
    final results = <_RunResult>[];

    for (final device in selected) {
      final ssh = SshService();
      try {
        final ok = await ssh.connect(device);
        if (!ok) {
          results.add(_RunResult(device.name, 'Не удалось подключиться'));
          continue;
        }

        for (final step in playbook.steps) {
          final output = await ssh.executeCommand(step.command);
          results.add(_RunResult(device.name, '${step.title}: ${output.trim()}'));
        }
      } catch (e) {
        results.add(_RunResult(device.name, 'Ошибка: $e'));
      } finally {
        await ssh.disconnect();
      }
    }

    if (!mounted) return;
    setState(() => _loading = false);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Результаты'),
        content: SizedBox(
          width: 600,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: results.length,
            itemBuilder: (context, index) {
              final res = results[index];
              return ListTile(
                title: Text(res.device),
                subtitle: Text(res.output),
              );
            },
          ),
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

  Future<List<LinuxDevice>?> _selectDevices(List<LinuxDevice> devices) async {
    final selected = <String>{};
    final groups = <String, List<LinuxDevice>>{};
    for (final d in devices) {
      final group = (d.group ?? '').trim().isEmpty ? 'Без группы' : d.group!;
      groups.putIfAbsent(group, () => []).add(d);
    }
    final groupNames = groups.keys.toList()..sort();

    return showDialog<List<LinuxDevice>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выбор машин'),
        content: SizedBox(
          width: 500,
          height: 420,
          child: ListView.builder(
            itemCount: groupNames.length,
            itemBuilder: (context, index) {
              final group = groupNames[index];
              final list = groups[group] ?? [];
              final selectedCount =
                  list.where((d) => selected.contains(d.id)).length;
              final allSelected = selectedCount == list.length && list.isNotEmpty;
              return Column(
                children: [
                  ListTile(
                    title: Text(group),
                    leading: Checkbox(
                      value: allSelected
                          ? true
                          : selectedCount == 0
                              ? false
                              : null,
                      tristate: true,
                      onChanged: (value) {
                        if (value == true) {
                          selected.addAll(list.map((d) => d.id));
                        } else {
                          selected.removeAll(list.map((d) => d.id));
                        }
                        (context as Element).markNeedsBuild();
                      },
                    ),
                  ),
                  for (final device in list)
                    CheckboxListTile(
                      value: selected.contains(device.id),
                      onChanged: (value) {
                        if (value == true) {
                          selected.add(device.id);
                        } else {
                          selected.remove(device.id);
                        }
                        (context as Element).markNeedsBuild();
                      },
                      title: Text(device.name),
                      subtitle: Text('${device.username}@${device.host}'),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final list = devices.where((d) => selected.contains(d.id)).toList();
              Navigator.pop(context, list);
            },
            child: const Text('Выбрать'),
          ),
        ],
      ),
    );
  }
}

class _Playbook {
  final String name;
  final List<_PlaybookStep> steps;

  _Playbook({required this.name, required this.steps});

  Map<String, dynamic> toJson() => {
        'name': name,
        'steps': steps.map((s) => s.toJson()).toList(),
      };

  factory _Playbook.fromJson(Map<String, dynamic> json) {
    return _Playbook(
      name: json['name'] as String? ?? 'Playbook',
      steps: (json['steps'] as List<dynamic>? ?? [])
          .map((e) => _PlaybookStep.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

class _PlaybookStep {
  String title;
  String command;

  _PlaybookStep(this.title, this.command);

  Map<String, dynamic> toJson() => {
        'title': title,
        'command': command,
      };

  factory _PlaybookStep.fromJson(Map<String, dynamic> json) {
    return _PlaybookStep(
      json['title'] as String? ?? 'Шаг',
      json['command'] as String? ?? '',
    );
  }
}

class _RunResult {
  final String device;
  final String output;

  _RunResult(this.device, this.output);
}
