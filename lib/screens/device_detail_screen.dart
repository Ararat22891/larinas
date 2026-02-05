import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/linux_device.dart';
import '../providers/device_provider.dart';
import 'monitoring_screen.dart';
import 'file_manager_screen.dart';
import 'services_screen.dart';
import 'scheduler_screen.dart';
import 'terminal_screen.dart';
import 'jmx_screen.dart';
import 'device_form_screen.dart';

class DeviceDetailScreen extends StatefulWidget {
  final LinuxDevice device;

  const DeviceDetailScreen({super.key, required this.device});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final isConnected = deviceProvider.isConnected &&
        deviceProvider.selectedDevice?.id == widget.device.id;
    final isLoading = deviceProvider.isLoading;
    final error = deviceProvider.error;
    final isWide = MediaQuery.of(context).size.width >= 1000;

    return Scaffold(
      appBar: isWide
          ? null
          : AppBar(
              elevation: 0,
              title: Text(
                widget.device.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              actions: [
                if (isConnected)
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Обновить',
                    onPressed: () {
                      deviceProvider.refreshSystemStats();
                    },
                  ),
                IconButton(
                  icon: Icon(isConnected ? Icons.link_off : Icons.link),
                  tooltip: isConnected ? 'Отключиться' : 'Подключиться',
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (isConnected) {
                            await deviceProvider.disconnect();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Отключено от устройства'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          } else {
                            final success = await deviceProvider.connectToDevice(widget.device);
                            if (mounted) {
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Успешно подключено!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              } else if (deviceProvider.error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(deviceProvider.error!),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                  ),
                                );
                              }
                            }
                          }
                        },
                ),
                IconButton(
                  icon: const Icon(Icons.manage_accounts_outlined),
                  tooltip: 'Сменить пользователя',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DeviceFormScreen(device: widget.device),
                      ),
                    );
                  },
                ),
              ],
            ),
      body: isConnected
          ? (isWide
              ? Row(
                  children: [
                    _SideNav(
                      deviceName: widget.device.name,
                      isConnected: isConnected,
                      selectedIndex: _selectedIndex,
                      onSelect: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      onBack: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          _CommandBar(
                            title: _sectionTitle(_selectedIndex),
                            onRefresh: isConnected
                                ? () => deviceProvider.refreshSystemStats()
                                : null,
                            onEdit: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DeviceFormScreen(device: widget.device),
                                ),
                              );
                            },
                            onToggleConnection: () async {
                              if (isConnected) {
                                await deviceProvider.disconnect();
                              } else {
                                await deviceProvider.connectToDevice(widget.device);
                              }
                            },
                            isConnected: isConnected,
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: IndexedStack(
                              index: _selectedIndex,
                              children: const [
                                MonitoringScreen(),
                                FileManagerScreen(),
                                ServicesScreen(),
                                SchedulerScreen(),
                                TerminalScreen(),
                                JmxScreen(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : IndexedStack(
                  index: _selectedIndex,
                  children: const [
                    MonitoringScreen(),
                    FileManagerScreen(),
                    ServicesScreen(),
                    SchedulerScreen(),
                    TerminalScreen(),
                    JmxScreen(),
                  ],
                ))
          : _buildConnectionScreen(context, deviceProvider, isLoading, error),
      bottomNavigationBar: isConnected && !isWide
          ? BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.monitor),
                  label: 'Мониторинг',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.folder),
                  label: 'Файлы',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: 'Службы',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.schedule),
                  label: 'Планировщик',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.terminal),
                  label: 'Терминал',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.analytics_outlined),
                  label: 'JMX',
                ),
              ],
            )
          : null,
    );
  }

  Widget _buildConnectionScreen(
    BuildContext context,
    DeviceProvider deviceProvider,
    bool isLoading,
    String? error,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Назад к устройствам'),
                ),
              ),
              const SizedBox(height: 8),
              // Иконка устройства
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.computer_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              
              // Информация об устройстве
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Информация об устройстве',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildInfoRow(
                        context,
                        Icons.computer,
                        'Название',
                        widget.device.name,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        Icons.dns,
                        'Адрес',
                        widget.device.host,
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        Icons.padding,
                        'Порт',
                        widget.device.port.toString(),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        context,
                        Icons.person,
                        'Пользователь',
                        widget.device.username,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Сообщение об ошибке
              if (error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Кнопки подключения и смены пользователя
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: isLoading
                          ? null
                          : () async {
                              deviceProvider.clearError();
                              final success =
                                  await deviceProvider.connectToDevice(widget.device);
                              if (mounted) {
                                if (success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Успешно подключено!'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                } else if (deviceProvider.error != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(deviceProvider.error!),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 5),
                                    ),
                                  );
                                }
                              }
                            },
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.link),
                      label: Text(isLoading ? 'Подключение...' : 'Подключиться'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                DeviceFormScreen(device: widget.device),
                          ),
                        );
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                      label: const Text('Сменить пользователя'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

class _SideNav extends StatelessWidget {
  final String deviceName;
  final bool isConnected;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;

  const _SideNav({
    required this.deviceName,
    required this.isConnected,
    required this.selectedIndex,
    required this.onSelect,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = const [
      _NavItem(Icons.monitor, 'Мониторинг'),
      _NavItem(Icons.folder, 'Файлы'),
      _NavItem(Icons.settings, 'Службы'),
      _NavItem(Icons.schedule, 'Планировщик'),
      _NavItem(Icons.terminal, 'Терминал'),
      _NavItem(Icons.analytics_outlined, 'JMX'),
    ];

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          right: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Все устройства'),
                ),
                const SizedBox(height: 8),
                Text(
                  deviceName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isConnected ? Icons.check_circle : Icons.error_outline,
                      size: 14,
                      color: isConnected ? Colors.green : Colors.redAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected ? 'Подключено' : 'Не подключено',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIndex == index;
                return ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  selected: isSelected,
                  selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.08),
                  onTap: () => onSelect(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem(this.icon, this.label);
}

class _CommandBar extends StatelessWidget {
  final String title;
  final VoidCallback? onRefresh;
  final VoidCallback onEdit;
  final VoidCallback onToggleConnection;
  final bool isConnected;

  const _CommandBar({
    required this.title,
    this.onRefresh,
    required this.onEdit,
    required this.onToggleConnection,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
          const SizedBox(width: 8),
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

String _sectionTitle(int index) {
  switch (index) {
    case 0:
      return 'Мониторинг';
    case 1:
      return 'Файлы';
    case 2:
      return 'Службы';
    case 3:
      return 'Планировщик';
    case 4:
      return 'Терминал';
    case 5:
      return 'JMX';
    default:
      return 'Раздел';
  }
}
