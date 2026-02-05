import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';

enum ScheduleType {
  once,
  daily,
  weekly,
  weekdays,
  custom,
}

class SchedulerScreen extends StatefulWidget {
  const SchedulerScreen({super.key});

  @override
  State<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends State<SchedulerScreen> {
  bool _isLoading = false;
  String? _error;
  List<_CronEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCrontab());
  }

  Future<void> _loadCrontab() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ssh = context.read<DeviceProvider>().sshService;
      final raw = await ssh.getCrontab();
      setState(() {
        _entries = _parseEntries(raw);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки задач: $e';
        _isLoading = false;
      });
    }
  }

  List<_CronEntry> _parseEntries(String raw) {
    final entries = <_CronEntry>[];
    final lines = raw.split('\n');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length < 6) continue;

      final schedule = parts.sublist(0, 5).join(' ');
      final command = parts.sublist(5).join(' ');
      entries.add(_CronEntry(schedule: schedule, command: command, raw: trimmed));
    }

    return entries;
  }

  Future<void> _saveEntry(_CronBuilder builder) async {
    final ssh = context.read<DeviceProvider>().sshService;
    final current = await ssh.getCrontab();
    final line = builder.toCronLine();
    final updated = current.trimRight();
    final next = updated.isEmpty ? '$line\n' : '$updated\n$line\n';
    await ssh.setCrontab(next);
    await _loadCrontab();
  }

  Future<void> _deleteEntry(_CronEntry entry) async {
    final ssh = context.read<DeviceProvider>().sshService;
    final current = await ssh.getCrontab();
    final lines = current.split('\n');
    final updated = lines.where((line) => line.trim() != entry.raw.trim()).join('\n');
    await ssh.setCrontab('${updated.trimRight()}\n');
    await _loadCrontab();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadCrontab,
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Text(
                'Планировщик задач',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _loadCrontab,
                icon: const Icon(Icons.refresh),
                tooltip: 'Обновить',
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Создать задачу'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _entries.isEmpty
              ? const Center(child: Text('Задачи не найдены'))
              : ListView.separated(
                  itemCount: _entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return ListTile(
                      title: Text(entry.command),
                      subtitle: Text(entry.schedule),
                      trailing: IconButton(
                        onPressed: () => _deleteEntry(entry),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Удалить',
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCreateDialog(BuildContext context) {
    final builder = _CronBuilder();
    final commandController = TextEditingController();
    final timeController = TextEditingController(text: '12:00');
    final dateController = TextEditingController();
    final daySet = <int>{};

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Новая задача'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<ScheduleType>(
                      initialValue: builder.type,
                      decoration: const InputDecoration(labelText: 'Тип расписания'),
                      items: const [
                        DropdownMenuItem(
                          value: ScheduleType.once,
                          child: Text('Один раз'),
                        ),
                        DropdownMenuItem(
                          value: ScheduleType.daily,
                          child: Text('Ежедневно'),
                        ),
                        DropdownMenuItem(
                          value: ScheduleType.weekdays,
                          child: Text('По будням'),
                        ),
                        DropdownMenuItem(
                          value: ScheduleType.weekly,
                          child: Text('Еженедельно'),
                        ),
                        DropdownMenuItem(
                          value: ScheduleType.custom,
                          child: Text('Выбор дней'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => builder.type = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Время (HH:MM)',
                        hintText: 'например 03:30',
                      ),
                    ),
                    if (builder.type == ScheduleType.once) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: dateController,
                        decoration: const InputDecoration(
                          labelText: 'Дата (YYYY-MM-DD)',
                          hintText: 'например 2026-03-01',
                        ),
                      ),
                    ],
                    if (builder.type == ScheduleType.weekly ||
                        builder.type == ScheduleType.custom ||
                        builder.type == ScheduleType.weekdays) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 6,
                        children: _weekdayChips(daySet, setState),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: commandController,
                      decoration: const InputDecoration(
                        labelText: 'Команда',
                        hintText: 'например systemctl restart nginx',
                      ),
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _TemplateChip(
                          label: 'Перезапуск nginx',
                          onTap: () => commandController.text = 'systemctl restart nginx',
                        ),
                        _TemplateChip(
                          label: 'Очистка логов',
                          onTap: () => commandController.text = 'journalctl --vacuum-time=7d',
                        ),
                        _TemplateChip(
                          label: 'Обновление системы',
                          onTap: () => commandController.text = 'sudo apt update && sudo apt -y upgrade',
                        ),
                      ],
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
                  onPressed: () async {
                    final command = commandController.text.trim();
                    if (command.isEmpty) return;
                    final time = timeController.text.trim();
                    if (!_validateTime(time)) return;
                    builder.time = time;
                    builder.command = command;
                    builder.days = daySet.toList()..sort();
                    builder.date = dateController.text.trim();

                    Navigator.pop(context);
                    await _saveEntry(builder);
                  },
                  child: const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  bool _validateTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return false;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return false;
    return h >= 0 && h <= 23 && m >= 0 && m <= 59;
  }

  List<Widget> _weekdayChips(Set<int> daySet, void Function(void Function()) setState) {
    const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return List.generate(labels.length, (index) {
      final day = index + 1;
      final selected = daySet.contains(day);
      return FilterChip(
        label: Text(labels[index]),
        selected: selected,
        onSelected: (value) {
          setState(() {
            if (value) {
              daySet.add(day);
            } else {
              daySet.remove(day);
            }
          });
        },
      );
    });
  }
}

class _TemplateChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TemplateChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}

class _CronBuilder {
  ScheduleType type = ScheduleType.daily;
  String time = '12:00';
  String command = '';
  List<int> days = [];
  String date = '';

  String toCronLine() {
    final timeParts = time.split(':');
    final minute = timeParts[1];
    final hour = timeParts[0];

    switch (type) {
      case ScheduleType.once:
        final parts = date.split('-');
        if (parts.length == 3) {
          final day = parts[2];
          final month = parts[1];
          return '$minute $hour $day $month * $command';
        }
        return '$minute $hour * * * $command';
      case ScheduleType.daily:
        return '$minute $hour * * * $command';
      case ScheduleType.weekdays:
        return '$minute $hour * * 1-5 $command';
      case ScheduleType.weekly:
        final day = days.isEmpty ? 1 : days.first;
        return '$minute $hour * * $day $command';
      case ScheduleType.custom:
        final dayList = days.isEmpty ? '1' : days.join(',');
        return '$minute $hour * * $dayList $command';
    }
  }
}

class _CronEntry {
  final String schedule;
  final String command;
  final String raw;

  _CronEntry({
    required this.schedule,
    required this.command,
    required this.raw,
  });
}
