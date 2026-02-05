import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import '../models/linux_device.dart';
import '../services/ssh_service.dart';
import 'device_form_screen.dart';
import 'device_detail_screen.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width >= 1100;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Linux Устройства',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: () {
              context.read<DeviceProvider>().loadDevices();
            },
          ),
        ],
      ),
      body: Consumer<DeviceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.devices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.devices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (provider.error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        provider.error!,
                        style: TextStyle(color: Colors.red.shade700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.computer_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Нет добавленных устройств',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Нажмите + чтобы добавить устройство',
                    style: TextStyle(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
            );
          }

          final groups = _groupDevices(provider.devices);
          final groupNames = groups.keys.toList()..sort();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (_selectedIds.isNotEmpty)
                  _buildSelectionBar(context, provider, isWide),
                _buildHeaderRow(context, isWide),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: groupNames.length,
                      itemBuilder: (context, index) {
                        final groupName = groupNames[index];
                        final devices = groups[groupName] ?? [];
                        return _buildGroupSection(
                          context,
                          provider,
                          groupName,
                          devices,
                          isWide,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const DeviceFormScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
    );
  }

  Widget _buildHeaderRow(BuildContext context, bool isWide) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Checkbox(
              value: _selectedIds.isNotEmpty &&
                  _selectedIds.length == _getAllDeviceIds(context).length,
              tristate: true,
              onChanged: (value) {
                final allIds = _getAllDeviceIds(context);
                setState(() {
                  if (value == true) {
                    _selectedIds.addAll(allIds);
                  } else {
                    _selectedIds.clear();
                  }
                });
              },
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Имя',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Адрес',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isWide)
            Expanded(
              flex: 2,
              child: Text(
                'Группа',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            flex: 2,
            child: Text(
              'Статус',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    DeviceProvider provider,
    String groupName,
    List<LinuxDevice> devices,
    bool isWide,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildGroupHeader(context, groupName, devices),
        for (final device in devices)
          _buildDeviceRow(context, provider, device, isWide),
      ],
    );
  }

  Widget _buildGroupHeader(
    BuildContext context,
    String groupName,
    List<LinuxDevice> devices,
  ) {
    final theme = Theme.of(context);
    final ids = devices.map((d) => d.id).toSet();
    final selectedCount = ids.where(_selectedIds.contains).length;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selectedCount == ids.length && ids.isNotEmpty
                ? true
                : selectedCount == 0
                    ? false
                    : null,
            tristate: true,
            onChanged: (value) {
              setState(() {
                if (value == true) {
                  _selectedIds.addAll(ids);
                } else {
                  _selectedIds.removeAll(ids);
                }
              });
            },
          ),
          Text(
            groupName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${devices.length})',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(
    BuildContext context,
    DeviceProvider provider,
    LinuxDevice device,
    bool isWide,
  ) {
    final status = _computeStatus(device);
    return Container(
      height: 52,
      margin: const EdgeInsets.only(top: 0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: InkWell(
        onTap: () {
          if (_selectedIds.isNotEmpty) {
            setState(() {
              if (_selectedIds.contains(device.id)) {
                _selectedIds.remove(device.id);
              } else {
                _selectedIds.add(device.id);
              }
            });
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceDetailScreen(device: device),
            ),
          );
        },
        onLongPress: () {
          setState(() {
            _selectedIds.add(device.id);
          });
        },
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Checkbox(
                value: _selectedIds.contains(device.id),
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
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  device.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${device.username}@${device.host}:${device.port}',
                style: TextStyle(color: Theme.of(context).hintColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isWide)
              Expanded(
                flex: 2,
                child: Text(
                  (device.group ?? 'Без группы'),
                  style: TextStyle(color: Theme.of(context).hintColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(
                    status.icon,
                    size: 14,
                    color: status.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    status.label,
                    style: TextStyle(color: status.color),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'delete') {
                  _showDeleteDialog(context, provider, device);
                } else if (value == 'edit') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DeviceFormScreen(device: device),
                    ),
                  );
                } else if (value == 'connect') {
                  provider.connectToDevice(device);
                } else if (value == 'disconnect') {
                  provider.disconnect();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: device.isConnected ? 'disconnect' : 'connect',
                  child: Row(
                    children: [
                      Icon(
                        device.isConnected ? Icons.link_off : Icons.link,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(device.isConnected ? 'Отключить' : 'Подключить'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Редактировать'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Удалить', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    DeviceProvider provider,
    LinuxDevice device,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Удалить устройство?'),
        content: Text('Вы уверены, что хотите удалить "${device.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteDevice(device.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Устройство "${device.name}" удалено'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text(
              'Удалить',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar(
    BuildContext context,
    DeviceProvider provider,
    bool isWide,
  ) {
    final selected = provider.devices.where((d) => _selectedIds.contains(d.id)).toList();
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: 12),
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
            onPressed: () => _showBulkCommandDialog(context, selected),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Команда'),
          ),
          if (isWide) const SizedBox(width: 8),
          if (isWide)
            OutlinedButton.icon(
              onPressed: () => _showBulkConnectDialog(context, selected),
              icon: const Icon(Icons.link),
              label: const Text('Подключить'),
            ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => _selectedIds.clear());
            },
            icon: const Icon(Icons.clear),
            label: const Text('Снять выбор'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkConnectDialog(
    BuildContext context,
    List<LinuxDevice> devices,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Массовое подключение'),
        content: Text('Будет выполнено подключение к ${devices.length} машинам по очереди.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _runBulkCommand(context, devices, 'echo connected');
            },
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBulkCommandDialog(
    BuildContext context,
    List<LinuxDevice> devices,
  ) async {
    final controller = TextEditingController();

    final command = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Команда для группы'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Команда',
            hintText: 'например systemctl restart nginx',
          ),
          style: const TextStyle(fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Запустить'),
          ),
        ],
      ),
    );

    if (command == null || command.isEmpty) return;
    await _runBulkCommand(context, devices, command);
  }

  Future<void> _runBulkCommand(
    BuildContext context,
    List<LinuxDevice> devices,
    String command,
  ) async {
    final results = <_BulkResult>[];

    for (final device in devices) {
      final service = SshService();
      try {
        final ok = await service.connect(device);
        if (!ok) {
          results.add(_BulkResult(device.name, 'Не удалось подключиться'));
        } else {
          final output = await service.executeCommand(command);
          results.add(_BulkResult(device.name, output.isEmpty ? 'OK' : output));
        }
      } catch (e) {
        results.add(_BulkResult(device.name, 'Ошибка: $e'));
      } finally {
        await service.disconnect();
      }
    }

    if (!context.mounted) return;
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
                title: Text(res.deviceName),
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

  Map<String, List<LinuxDevice>> _groupDevices(List<LinuxDevice> devices) {
    final map = <String, List<LinuxDevice>>{};
    for (final device in devices) {
      final group = (device.group ?? '').trim().isEmpty ? 'Без группы' : device.group!;
      map.putIfAbsent(group, () => []).add(device);
    }
    return map;
  }

  Set<String> _getAllDeviceIds(BuildContext context) {
    final provider = context.read<DeviceProvider>();
    return provider.devices.map((d) => d.id).toSet();
  }
}

class _BulkResult {
  final String deviceName;
  final String output;

  _BulkResult(this.deviceName, this.output);
}

class _DeviceStatus {
  final String label;
  final IconData icon;
  final Color color;

  const _DeviceStatus(this.label, this.icon, this.color);
}

_DeviceStatus _computeStatus(LinuxDevice device) {
  if (device.isConnected) {
    return const _DeviceStatus('Подключено', Icons.check_circle, Colors.green);
  }

  if (device.lastSeen != null) {
    return const _DeviceStatus('Доступно', Icons.circle_outlined, Colors.blueGrey);
  }

  return const _DeviceStatus('Оффлайн', Icons.error_outline, Colors.grey);
}
