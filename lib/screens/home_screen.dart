import 'package:flutter/material.dart';
import 'devices_screen.dart';
import 'log_collector_screen.dart';
import 'playbook_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linux Control Center'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: isWide
                ? Row(
                    children: [
                      Expanded(
                        child: _ModeCard(
                          title: 'Работа с машинами',
                          description:
                              'Управление серверами, мониторинг, файлы, службы и терминал.',
                          icon: Icons.dns_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DevicesScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ModeCard(
                          title: 'Сбор логов',
                          description:
                              'Сбор, сортировка и обрезка логов с выбранных машин.',
                          icon: Icons.fact_check_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const LogCollectorScreen()),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ModeCard(
                          title: 'Playbook',
                          description:
                              'Сценарии действий для массового выполнения команд.',
                          icon: Icons.auto_awesome_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PlaybookScreen()),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _ModeCard(
                        title: 'Работа с машинами',
                        description:
                            'Управление серверами, мониторинг, файлы, службы и терминал.',
                        icon: Icons.dns_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const DevicesScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ModeCard(
                        title: 'Сбор логов',
                        description:
                            'Сбор, сортировка и обрезка логов с выбранных машин.',
                        icon: Icons.fact_check_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LogCollectorScreen()),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      _ModeCard(
                        title: 'Playbook',
                        description:
                            'Сценарии действий для массового выполнения команд.',
                        icon: Icons.auto_awesome_outlined,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PlaybookScreen()),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onTap,
                child: const Text('Открыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
