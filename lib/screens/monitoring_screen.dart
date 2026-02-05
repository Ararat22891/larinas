import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/device_provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeviceProvider>();
      provider.refreshSystemStats();
      
      // Auto-refresh every 5 seconds
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
        if (mounted) {
          provider.refreshSystemStats();
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.systemStats == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final stats = provider.systemStats;
        if (stats == null) {
          return const Center(
            child: Text('Нет данных о системе'),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshSystemStats(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatsGrid(context, stats),
              const SizedBox(height: 16),
              _buildSystemIdentity(context, stats),
              const SizedBox(height: 16),
              _buildServicesSummary(context, stats),
              const SizedBox(height: 16),
              _ServiceMonitorPanel(),
              const SizedBox(height: 16),
              _buildDetailsCard(context, stats),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(BuildContext context, stats) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final cards = [
      _buildStatCard(
        'Процессор',
        '${stats.cpuUsage.toStringAsFixed(1)}%',
        stats.cpuUsage / 100,
        const Color(0xFF2563EB),
        Icons.memory,
        subtitle: 'Нагрузка ядер в реальном времени',
      ),
      _buildStatCard(
        'Память',
        '${stats.memoryUsage.toStringAsFixed(1)}%',
        stats.memoryUsage / 100,
        const Color(0xFF16A34A),
        Icons.storage,
        subtitle:
            '${_formatBytes(stats.memoryUsed.toInt())} / ${_formatBytes(stats.memoryTotal.toInt())}',
      ),
      _buildStatCard(
        'Диск',
        '${stats.diskUsage.toStringAsFixed(1)}%',
        stats.diskUsage / 100,
        const Color(0xFFF97316),
        Icons.disc_full,
        subtitle:
            '${_formatBytes(stats.diskUsed.toInt())} / ${_formatBytes(stats.diskTotal.toInt())}',
      ),
    ];

    if (isWide) {
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: cards
            .map((card) => SizedBox(width: 280, child: card))
            .toList(),
      );
    }

    return Column(
      children: [
        for (final card in cards) ...[
          card,
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildDetailsCard(BuildContext context, stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Дополнительная информация',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Время работы', stats.uptime),
            _buildInfoRow('Процессов', stats.processes.toString()),
            _buildInfoRow(
              'Средняя загрузка',
              '${stats.loadAverage1.toStringAsFixed(2)} / ${stats.loadAverage5.toStringAsFixed(2)} / ${stats.loadAverage15.toStringAsFixed(2)}',
            ),
            _buildInfoRow(
              'Swap',
              '${_formatBytes(stats.swapUsed.toInt())} / ${_formatBytes(stats.swapTotal.toInt())} (${stats.swapUsage.toStringAsFixed(1)}%)',
            ),
            _buildInfoRow(
              'Сеть RX/TX',
              '${_formatBytes(stats.netRxBytes.toInt())} / ${_formatBytes(stats.netTxBytes.toInt())}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemIdentity(BuildContext context, stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Система',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Хост', stats.hostname.isEmpty ? '-' : stats.hostname),
            _buildInfoRow('ОС', stats.osName.isEmpty ? '-' : stats.osName),
            _buildInfoRow('Ядро', stats.kernel.isEmpty ? '-' : stats.kernel),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesSummary(BuildContext context, stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Службы',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildSummaryChip(
                  context,
                  'Active',
                  stats.servicesActive.toString(),
                  Colors.green,
                ),
                const SizedBox(width: 8),
                _buildSummaryChip(
                  context,
                  'Inactive',
                  stats.servicesInactive.toString(),
                  Colors.orange,
                ),
                const SizedBox(width: 8),
                _buildSummaryChip(
                  context,
                  'Failed',
                  stats.servicesFailed.toString(),
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryChip(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    double progress,
    Color color,
    IconData icon, {
    String? subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _ServiceMonitorPanel extends StatefulWidget {
  @override
  State<_ServiceMonitorPanel> createState() => _ServiceMonitorPanelState();
}

class _ServiceMonitorPanelState extends State<_ServiceMonitorPanel> {
  bool _loading = false;
  List<_ServiceMonitorItem> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final serviceNames = prefs.getStringList('monitored_services') ?? [];
    final ssh = context.read<DeviceProvider>().sshService;
    final items = <_ServiceMonitorItem>[];

    for (final service in serviceNames) {
      final rawFields = prefs.getStringList('service_monitor_fields_$service') ?? [];
      final fields = rawFields
          .map((entry) => _ServiceMonitorField.fromJson(entry))
          .where((field) => field.label.isNotEmpty && field.command.isNotEmpty)
          .toList();
      if (fields.isEmpty) continue;

      final results = <_ServiceMonitorResult>[];
      for (final field in fields) {
        try {
          final cmd = field.command.replaceAll('{service}', service);
          final output = await ssh.executeCommand(cmd);
          results.add(_ServiceMonitorResult(field.label, output.trim()));
        } catch (e) {
          results.add(_ServiceMonitorResult(field.label, 'Ошибка: $e'));
        }
      }
      items.add(_ServiceMonitorItem(service, results));
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Мониторинг служб',
                  style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Обновить'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_items.isEmpty)
              const Text('Службы для мониторинга не выбраны')
            else
              Column(
                children: _items.map((item) {
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.serviceName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        for (final res in item.results)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 180,
                                  child: Text(
                                    res.label,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    res.value.isEmpty ? '-' : res.value,
                                    style: const TextStyle(fontFamily: 'monospace'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
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

class _ServiceMonitorItem {
  final String serviceName;
  final List<_ServiceMonitorResult> results;

  _ServiceMonitorItem(this.serviceName, this.results);
}

class _ServiceMonitorResult {
  final String label;
  final String value;

  _ServiceMonitorResult(this.label, this.value);
}
