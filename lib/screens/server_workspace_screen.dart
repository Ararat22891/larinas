import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/linux_device.dart';
import '../providers/device_provider.dart';
import 'device_form_screen.dart';
import 'file_manager_screen.dart';
import 'log_collector_screen.dart';
import 'scheduler_screen.dart';
import 'services_screen.dart';
import 'terminal_screen.dart';
import 'web_console_screen.dart';

class ServerWorkspaceScreen extends StatefulWidget {
  const ServerWorkspaceScreen({super.key});

  @override
  State<ServerWorkspaceScreen> createState() => _ServerWorkspaceScreenState();
}

class _ServerWorkspaceScreenState extends State<ServerWorkspaceScreen> {
  LinuxDevice? _selectedDevice;
  int _tabIndex = 0;
  String _search = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<DeviceProvider>();
    if (_selectedDevice == null && provider.devices.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_selectedDevice != null || provider.devices.isEmpty) return;
        final device = provider.selectedDevice ?? provider.devices.first;
        setState(() => _selectedDevice = device);
        provider.selectDevice(device);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Row(
          children: [
            _buildSidebar(context),
            Expanded(
              child: _buildWorkspace(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
              children: [
                Text(
                  'Серверы',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => context.read<DeviceProvider>().loadDevices(),
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Обновить',
                ),
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DeviceFormScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  tooltip: 'Добавить',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Поиск по имени или адресу',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value.trim()),
            ),
          ),
          Expanded(
            child: Consumer<DeviceProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.devices.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final groups = _groupDevices(
                  provider.devices.where((device) => _matchesSearch(device)).toList(),
                );
                final groupNames = groups.keys.toList()..sort();

                if (groupNames.isEmpty) {
                  return _buildEmptySidebar(context);
                }

                return ListView.builder(
                  itemCount: groupNames.length,
                  itemBuilder: (context, index) {
                    final groupName = groupNames[index];
                    final devices = groups[groupName] ?? [];
                    return _buildGroupSection(context, provider, groupName, devices);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySidebar(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.computer_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'Нет устройств',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Добавьте сервер для начала работы',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context,
    DeviceProvider provider,
    String groupName,
    List<LinuxDevice> devices,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                Text(
                  groupName,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.hintColor,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${devices.length}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
          for (final device in devices) _buildDeviceRow(context, provider, device),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(
    BuildContext context,
    DeviceProvider provider,
    LinuxDevice device,
  ) {
    final theme = Theme.of(context);
    final status = _computeStatusFor(provider, device);
    final isSelected = _selectedDevice?.id == device.id;

    return InkWell(
      onTap: () => _selectDevice(context, provider, device),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${device.username}@${device.host}:${device.port}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _toggleConnection(context, provider, device),
              tooltip: device.isConnected ? 'Отключить' : 'Подключить',
              icon: Icon(device.isConnected ? Icons.link_off : Icons.link),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkspace(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DeviceProvider>();
    final selected = _selectedDevice;

    if (selected == null) {
      return _buildEmptyWorkspace(context);
    }

    final isConnected =
        provider.isConnected && provider.selectedDevice?.id == selected.id;

    return Column(
      children: [
        _WorkspaceHeader(
          device: selected,
          isConnected: isConnected,
          status: _computeStatusFor(provider, selected),
          onEdit: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DeviceFormScreen(device: selected),
              ),
            );
          },
          onToggleConnection: () => _toggleConnection(context, provider, selected),
          onRefresh: isConnected ? provider.refreshSystemStats : null,
        ),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              _TabChip(
                label: 'Файлы',
                isActive: _tabIndex == 0,
                onTap: () => setState(() => _tabIndex = 0),
              ),
              _TabChip(
                label: 'Службы',
                isActive: _tabIndex == 1,
                onTap: () => setState(() => _tabIndex = 1),
              ),
              _TabChip(
                label: 'Логи',
                isActive: _tabIndex == 2,
                onTap: () => setState(() => _tabIndex = 2),
              ),
              _TabChip(
                label: 'Терминал',
                isActive: _tabIndex == 3,
                onTap: () => setState(() => _tabIndex = 3),
              ),
              _TabChip(
                label: 'Планировщик',
                isActive: _tabIndex == 4,
                onTap: () => setState(() => _tabIndex = 4),
              ),
              _TabChip(
                label: 'Web',
                isActive: _tabIndex == 5,
                onTap: () => setState(() => _tabIndex = 5),
              ),
            ],
          ),
        ),
        Expanded(
          child: isConnected
              ? IndexedStack(
                  index: _tabIndex,
                  children: const [
                    FileManagerScreen(),
                    ServicesScreen(),
                    LogCollectorScreen(),
                    TerminalScreen(),
                    SchedulerScreen(),
                    WebConsoleScreen(),
                  ],
                )
              : _buildConnectPanel(context, provider, selected),
        ),
      ],
    );
  }

  Widget _buildEmptyWorkspace(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storage_outlined, size: 64, color: theme.hintColor),
          const SizedBox(height: 12),
          Text(
            'Выберите сервер слева',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Слева доступен список машин и групп',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectPanel(
    BuildContext context,
    DeviceProvider provider,
    LinuxDevice device,
  ) {
    final theme = Theme.of(context);
    final isLoading = provider.isLoading;
    final error = provider.error;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Подключение к серверу',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${device.username}@${device.host}:${device.port}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      error,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => _connectToDevice(context, provider, device),
                      icon: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.link),
                      label: Text(isLoading ? 'Подключение...' : 'Подключиться'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DeviceFormScreen(device: device),
                          ),
                        );
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Сменить пользователя'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _connectToDevice(
    BuildContext context,
    DeviceProvider provider,
    LinuxDevice device,
  ) async {
    provider.clearError();
    provider.selectDevice(device);
    final success = await provider.connectToDevice(device);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Успешно подключено!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _toggleConnection(
    BuildContext context,
    DeviceProvider provider,
    LinuxDevice device,
  ) async {
    if (provider.isConnected && provider.selectedDevice?.id == device.id) {
      await provider.disconnect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Отключено от устройства'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      await _connectToDevice(context, provider, device);
    }
  }

  Future<void> _selectDevice(
    BuildContext context,
    DeviceProvider provider,
    LinuxDevice device,
  ) async {
    if (provider.isConnected &&
        provider.selectedDevice != null &&
        provider.selectedDevice!.id != device.id) {
      final shouldSwitch = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Переключить устройство?'),
          content: const Text('Текущее подключение будет отключено. Продолжить?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Переключить'),
            ),
          ],
        ),
      );
      if (shouldSwitch != true) return;
      await provider.disconnect();
    }

    setState(() => _selectedDevice = device);
    provider.selectDevice(device);
  }

  bool _matchesSearch(LinuxDevice device) {
    if (_search.isEmpty) return true;
    final query = _search.toLowerCase();
    return device.name.toLowerCase().contains(query) ||
        device.host.toLowerCase().contains(query) ||
        device.username.toLowerCase().contains(query);
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

class _WorkspaceHeader extends StatelessWidget {
  final LinuxDevice device;
  final bool isConnected;
  final _DeviceStatus status;
  final VoidCallback onEdit;
  final VoidCallback onToggleConnection;
  final VoidCallback? onRefresh;

  const _WorkspaceHeader({
    required this.device,
    required this.isConnected,
    required this.status,
    required this.onEdit,
    required this.onToggleConnection,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.storage_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${device.username}@${device.host}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Icon(status.icon, size: 14, color: status.color),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: theme.textTheme.bodySmall?.copyWith(color: status.color),
              ),
            ],
          ),
          const Spacer(),
          if (onRefresh != null)
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              tooltip: 'Обновить',
            ),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.manage_accounts_outlined),
            label: const Text('Сменить пользователя'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: onToggleConnection,
            icon: Icon(isConnected ? Icons.link_off : Icons.link),
            label: Text(isConnected ? 'Отключить' : 'Подключить'),
          ),
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _TabChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => onTap(),
        selectedColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          color: isActive ? theme.colorScheme.primary : theme.hintColor,
        ),
      ),
    );
  }
}

class _DeviceStatus {
  final String label;
  final IconData icon;
  final Color color;

  const _DeviceStatus(this.label, this.icon, this.color);
}

_DeviceStatus _computeStatusFor(DeviceProvider provider, LinuxDevice device) {
  final isActive = provider.isConnected && provider.selectedDevice?.id == device.id;
  if (isActive) {
    return const _DeviceStatus('Подключено', Icons.check_circle, Colors.green);
  }
  if (device.lastSeen != null) {
    return const _DeviceStatus('Доступно', Icons.circle_outlined, Colors.blueGrey);
  }
  return const _DeviceStatus('Оффлайн', Icons.error_outline, Colors.grey);
}
