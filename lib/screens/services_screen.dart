import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/device_provider.dart';
import '../providers/service_provider.dart';
import '../models/service.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final sshService = deviceProvider.sshService;
    
    if (!sshService.isConnected) {
      return const Center(child: Text('Не подключено к устройству'));
    }

    return ChangeNotifierProvider(
      create: (_) => ServiceProvider(sshService)..loadServices(),
      child: Consumer<ServiceProvider>(
        builder: (context, serviceProvider, child) {
          if (serviceProvider.isLoading && serviceProvider.services.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (serviceProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    serviceProvider.error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      serviceProvider.clearError();
                      serviceProvider.loadServices();
                    },
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          final filteredServices = _searchQuery.isEmpty
              ? serviceProvider.services
              : serviceProvider.services
                  .where((service) =>
                      service.name
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()) ||
                      service.description
                          .toLowerCase()
                          .contains(_searchQuery.toLowerCase()))
                  .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Поиск служб...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: filteredServices.isEmpty
                    ? const Center(child: Text('Службы не найдены'))
                    : RefreshIndicator(
                        onRefresh: () => serviceProvider.loadServices(),
                        child: ListView.builder(
                          itemCount: filteredServices.length,
                          itemBuilder: (context, index) {
                            final service = filteredServices[index];
                            return _buildServiceItem(context, serviceProvider, service);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildServiceItem(
    BuildContext context,
    ServiceProvider serviceProvider,
    Service service,
  ) {
    final statusColor = _getStatusColor(service.status);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(
            _getStatusIcon(service.status),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(service.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(service.description),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  service.statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                if (service.isEnabled)
                  const Text(
                    'Автозапуск',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (service.status == ServiceStatus.active)
                  ElevatedButton.icon(
                    onPressed: () => _stopService(context, serviceProvider, service),
                    icon: const Icon(Icons.stop),
                    label: const Text('Остановить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _startService(context, serviceProvider, service),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Запустить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _restartService(context, serviceProvider, service),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Перезапустить'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showLogsSheet(context, service.name),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Логи'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showInfoSheet(context, service.name),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('Инфо'),
                ),
                if (service.isEnabled)
                  ElevatedButton.icon(
                    onPressed: () => _disableService(context, serviceProvider, service),
                    icon: const Icon(Icons.block),
                    label: const Text('Отключить'),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () => _enableService(context, serviceProvider, service),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Включить'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.active:
        return Colors.green;
      case ServiceStatus.inactive:
        return Colors.grey;
      case ServiceStatus.failed:
        return Colors.red;
      case ServiceStatus.activating:
      case ServiceStatus.deactivating:
        return Colors.orange;
      case ServiceStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(ServiceStatus status) {
    switch (status) {
      case ServiceStatus.active:
        return Icons.check_circle;
      case ServiceStatus.inactive:
        return Icons.stop_circle;
      case ServiceStatus.failed:
        return Icons.error;
      case ServiceStatus.activating:
        return Icons.hourglass_empty;
      case ServiceStatus.deactivating:
        return Icons.hourglass_full;
      case ServiceStatus.unknown:
        return Icons.help_outline;
    }
  }

  Future<void> _startService(
    BuildContext context,
    ServiceProvider serviceProvider,
    Service service,
  ) async {
    final success = await serviceProvider.startService(service.name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Служба ${service.name} запущена'
                : 'Ошибка запуска службы ${service.name}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _stopService(
    BuildContext context,
    ServiceProvider serviceProvider,
    Service service,
  ) async {
    final success = await serviceProvider.stopService(service.name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Служба ${service.name} остановлена'
                : 'Ошибка остановки службы ${service.name}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _restartService(
    BuildContext context,
    ServiceProvider serviceProvider,
    Service service,
  ) async {
    final success = await serviceProvider.restartService(service.name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Служба ${service.name} перезапущена'
                : 'Ошибка перезапуска службы ${service.name}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _enableService(
    BuildContext context,
    ServiceProvider serviceProvider,
    Service service,
  ) async {
    final success = await serviceProvider.enableService(service.name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Автозапуск для ${service.name} включен'
                : 'Ошибка включения автозапуска для ${service.name}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _disableService(
    BuildContext context,
    ServiceProvider serviceProvider,
    Service service,
  ) async {
    final success = await serviceProvider.disableService(service.name);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Автозапуск для ${service.name} отключен'
                : 'Ошибка отключения автозапуска для ${service.name}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _showLogsSheet(BuildContext context, String serviceName) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ServiceLogsSheet(serviceName: serviceName),
    );
  }

  Future<void> _showInfoSheet(BuildContext context, String serviceName) async {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ServiceInfoSheet(serviceName: serviceName),
    );
  }
}

class _ServiceLogsSheet extends StatefulWidget {
  final String serviceName;

  const _ServiceLogsSheet({required this.serviceName});

  @override
  State<_ServiceLogsSheet> createState() => _ServiceLogsSheetState();
}

class _ServiceLogsSheetState extends State<_ServiceLogsSheet> {
  final TextEditingController _filterController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _logs = '';
  bool _loading = false;
  bool _autoRefresh = true;
  int _lines = 200;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_autoRefresh) {
        _fetchLogs();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _filterController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final ssh = context.read<DeviceProvider>().sshService;
      final logs = await ssh.getServiceLogs(widget.serviceName, lines: _lines);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = _filterController.text.trim();
    final lines = _logs.split('\n');
    final filtered = filter.isEmpty
        ? lines
        : lines.where((line) => line.toLowerCase().contains(filter.toLowerCase())).toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Логи ${widget.serviceName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                DropdownButton<int>(
                  value: _lines,
                  items: const [
                    DropdownMenuItem(value: 50, child: Text('50 строк')),
                    DropdownMenuItem(value: 100, child: Text('100 строк')),
                    DropdownMenuItem(value: 200, child: Text('200 строк')),
                    DropdownMenuItem(value: 500, child: Text('500 строк')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _lines = value);
                    _fetchLogs();
                  },
                ),
                const SizedBox(width: 12),
                Switch(
                  value: _autoRefresh,
                  onChanged: (value) => setState(() => _autoRefresh = value),
                ),
                const Text('Обновлять'),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _filterController,
              decoration: const InputDecoration(
                hintText: 'Фильтр по тексту',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final line = filtered[index];
                      return Text(
                        line,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: line.contains('error') || line.contains('failed')
                              ? Colors.redAccent
                              : theme.hintColor,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_loading) const CircularProgressIndicator(strokeWidth: 2),
                const Spacer(),
                TextButton(
                  onPressed: _fetchLogs,
                  child: const Text('Обновить'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceInfoTemplate {
  final String title;
  final String command;

  const _ServiceInfoTemplate(this.title, this.command);

  Map<String, dynamic> toJson() => {
        'title': title,
        'command': command,
      };

  factory _ServiceInfoTemplate.fromJson(Map<String, dynamic> json) {
    return _ServiceInfoTemplate(
      json['title'] as String? ?? '',
      json['command'] as String? ?? '',
    );
  }
}

class _ServiceInfoSheet extends StatefulWidget {
  final String serviceName;

  const _ServiceInfoSheet({required this.serviceName});

  @override
  State<_ServiceInfoSheet> createState() => _ServiceInfoSheetState();
}

class _ServiceInfoSheetState extends State<_ServiceInfoSheet> {
  List<_ServiceInfoTemplate> _templates = [];
  String _output = '';
  bool _loading = false;
  bool _monitored = false;
  List<_ServiceMonitorField> _monitorFields = [];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
    _loadMonitorConfig();
  }

  Future<void> _loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('service_info_templates');
    if (raw == null || raw.isEmpty) {
      _templates = _defaultTemplates();
      await _saveTemplates();
      if (!mounted) return;
      setState(() {});
      return;
    }

    _templates = raw
        .map((entry) => _ServiceInfoTemplate.fromJson(
              Map<String, dynamic>.from(jsonDecode(entry) as Map),
            ))
        .where((tpl) => tpl.title.isNotEmpty)
        .toList();
    if (mounted) setState(() {});
  }

  Future<void> _saveTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _templates.map((tpl) => jsonEncode(tpl.toJson())).toList();
    await prefs.setStringList('service_info_templates', raw);
  }

  Future<void> _loadMonitorConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final monitored = prefs.getStringList('monitored_services') ?? [];
    _monitored = monitored.contains(widget.serviceName);
    final rawFields =
        prefs.getStringList('service_monitor_fields_${widget.serviceName}') ?? [];
    _monitorFields = rawFields.map(_ServiceMonitorField.fromJson).toList();
    if (mounted) setState(() {});
  }

  Future<void> _saveMonitorConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final monitored = prefs.getStringList('monitored_services') ?? [];
    final set = monitored.toSet();
    if (_monitored) {
      set.add(widget.serviceName);
    } else {
      set.remove(widget.serviceName);
    }
    await prefs.setStringList('monitored_services', set.toList());
    final raw = _monitorFields.map((f) => f.toJson()).toList();
    await prefs.setStringList('service_monitor_fields_${widget.serviceName}', raw);
  }

  List<_ServiceInfoTemplate> _defaultTemplates() {
    return const [
      _ServiceInfoTemplate(
        'Статус systemctl',
        'systemctl status {service} --no-pager',
      ),
      _ServiceInfoTemplate(
        'Время активного состояния',
        'systemctl show {service} -p ActiveEnterTimestamp -p ActiveState',
      ),
      _ServiceInfoTemplate(
        'Юнит-файл',
        'systemctl cat {service} --no-pager',
      ),
      _ServiceInfoTemplate(
        'Порты (ss)',
        'ss -ltnp | grep -i {service} || echo "Порты не найдены"',
      ),
    ];
  }

  Future<void> _runTemplate(_ServiceInfoTemplate template) async {
    setState(() {
      _loading = true;
      _output = '';
    });

    final ssh = context.read<DeviceProvider>().sshService;
    final cmd = template.command.replaceAll('{service}', widget.serviceName);
    try {
      final output = await ssh.executeCommand(cmd);
      if (!mounted) return;
      setState(() {
        _output = output.isEmpty ? 'Нет вывода' : output;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _output = 'Ошибка: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addTemplate() async {
    final titleController = TextEditingController();
    final commandController = TextEditingController(text: 'systemctl show {service}');

    final result = await showDialog<_ServiceInfoTemplate>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новый шаблон'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commandController,
              decoration: const InputDecoration(
                labelText: 'Команда',
                hintText: 'Используйте {service} для имени службы',
              ),
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
            onPressed: () {
              final title = titleController.text.trim();
              final cmd = commandController.text.trim();
              if (title.isEmpty || cmd.isEmpty) return;
              Navigator.pop(context, _ServiceInfoTemplate(title, cmd));
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (result == null) return;
    setState(() => _templates.add(result));
    await _saveTemplates();
  }

  Future<void> _addMonitorField() async {
    final labelController = TextEditingController();
    final commandController = TextEditingController(text: 'systemctl show {service}');

    final result = await showDialog<_ServiceMonitorField>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Поле мониторинга'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commandController,
              decoration: const InputDecoration(
                labelText: 'Команда',
                hintText: 'Используйте {service} для имени службы',
              ),
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
            onPressed: () {
              final label = labelController.text.trim();
              final cmd = commandController.text.trim();
              if (label.isEmpty || cmd.isEmpty) return;
              Navigator.pop(context, _ServiceMonitorField(label, cmd));
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (result == null) return;
    setState(() => _monitorFields.add(result));
    await _saveMonitorConfig();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  'Информация: ${widget.serviceName}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _monitored,
                  onChanged: (value) async {
                    setState(() => _monitored = value);
                    await _saveMonitorConfig();
                  },
                ),
                const Text('Мониторинг'),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _addTemplate,
                  icon: const Icon(Icons.add),
                  label: const Text('Шаблон'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: ListView(
                      children: _templates
                          .map(
                            (tpl) => ListTile(
                              title: Text(tpl.title),
                              subtitle: Text(
                                tpl.command,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _runTemplate(tpl),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              child: Text(
                                _output.isEmpty ? 'Выберите шаблон' : _output,
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Поля мониторинга',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final field in _monitorFields)
                  Chip(
                    label: Text(field.label),
                    deleteIcon: const Icon(Icons.close),
                    onDeleted: () async {
                      setState(() => _monitorFields.remove(field));
                      await _saveMonitorConfig();
                    },
                  ),
                ActionChip(
                  label: const Text('Добавить поле'),
                  onPressed: _addMonitorField,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceMonitorField {
  final String label;
  final String command;

  const _ServiceMonitorField(this.label, this.command);

  factory _ServiceMonitorField.fromJson(String raw) {
    try {
      final parts = raw.split('||');
      if (parts.length >= 2) {
        return _ServiceMonitorField(parts[0], parts.sublist(1).join('||'));
      }
    } catch (_) {}
    return const _ServiceMonitorField('', '');
  }

  String toJson() => '$label||$command';
}
