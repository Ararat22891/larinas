import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JmxScreen extends StatefulWidget {
  const JmxScreen({super.key});

  @override
  State<JmxScreen> createState() => _JmxScreenState();
}

class _JmxScreenState extends State<JmxScreen> {
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _metricController = TextEditingController();
  final List<String> _metrics = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _userController.dispose();
    _passwordController.dispose();
    _metricController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _endpointController.text = prefs.getString('jmx_endpoint') ?? '';
    _userController.text = prefs.getString('jmx_user') ?? '';
    _passwordController.text = prefs.getString('jmx_pass') ?? '';
    _metrics
      ..clear()
      ..addAll(prefs.getStringList('jmx_metrics') ?? []);
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jmx_endpoint', _endpointController.text.trim());
    await prefs.setString('jmx_user', _userController.text.trim());
    await prefs.setString('jmx_pass', _passwordController.text.trim());
    await prefs.setStringList('jmx_metrics', _metrics);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'JMX мониторинг',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _endpointController,
            decoration: const InputDecoration(
              labelText: 'Endpoint (JMX exporter / HTTP)',
              hintText: 'http://server:9404/metrics',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userController,
                  decoration: const InputDecoration(labelText: 'Пользователь'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Пароль'),
                  obscureText: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Метрики',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final metric in _metrics)
                Chip(
                  label: Text(metric),
                  onDeleted: () {
                    setState(() => _metrics.remove(metric));
                    _save();
                  },
                ),
              ActionChip(
                label: const Text('Добавить метрику'),
                onPressed: () async {
                  final value = await showDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Метрика'),
                      content: TextField(
                        controller: _metricController,
                        decoration: const InputDecoration(
                          hintText: 'java.lang:type=Memory/HeapMemoryUsage',
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Отмена'),
                        ),
                        ElevatedButton(
                          onPressed: () =>
                              Navigator.pop(context, _metricController.text.trim()),
                          child: const Text('Добавить'),
                        ),
                      ],
                    ),
                  );
                  if (value == null || value.isEmpty) return;
                  setState(() => _metrics.add(value));
                  _metricController.clear();
                  await _save();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Сохранить'),
              ),
              const SizedBox(width: 12),
              Text(
                'Подключение и сбор метрик будут реализованы после настройки endpoint.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
