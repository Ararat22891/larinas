import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';

import '../models/linux_device.dart';
import '../providers/device_provider.dart';
import '../services/secure_storage_service.dart';

class WebConsoleScreen extends StatefulWidget {
  const WebConsoleScreen({super.key});

  @override
  State<WebConsoleScreen> createState() => _WebConsoleScreenState();
}

class _WebConsoleScreenState extends State<WebConsoleScreen> {
  final WebviewController _controller = WebviewController();
  final TextEditingController _urlController = TextEditingController();
  bool _isReady = false;
  bool _webviewAvailable = true;
  List<_WebLink> _links = [];
  String? _activeId;
  String? _deviceId;
  final SecureStorageService _secureStorage = SecureStorageService();
  final Map<String, String?> _passwords = {};
  final Map<String, _LinkHealth> _health = {};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (Platform.isWindows) {
      try {
        await _controller.initialize();
        await _controller.setBackgroundColor(Colors.transparent);
        await _controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
        _webviewAvailable = true;
      } catch (_) {
        _webviewAvailable = false;
      }
    } else {
      _webviewAvailable = false;
    }
    await _loadLinks();
    if (!mounted) return;
    setState(() => _isReady = true);
  }

  Future<void> _loadLinks() async {
    final device = context.read<DeviceProvider>().selectedDevice;
    if (device == null) return;
    _deviceId = device.id;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_linksKey(device.id)) ?? [];
    final links = raw.map(_WebLink.fromStorage).toList();
    if (links.isEmpty) {
      links.addAll(_defaultLinks(device));
      await prefs.setStringList(
        _linksKey(device.id),
        links.map((e) => e.toStorage()).toList(),
      );
    }
    final passwords = <String, String?>{};
    for (final link in links) {
      passwords[link.id] = await _secureStorage.readSecret(_passwordKey(link.id));
    }
    if (!mounted) return;
    setState(() {
      _links = links;
      _passwords.clear();
      _passwords.addAll(passwords);
      if (_activeId == null && links.isNotEmpty) {
        _activeId = links.first.id;
      }
    });
    if (_activeId != null) {
      await _openLink(_activeId!, device);
    }
    _refreshHealth(device);
  }

  List<_WebLink> _defaultLinks(LinuxDevice device) {
    return [
      _WebLink(
        id: 'activemq',
        title: 'ActiveMQ Console',
        url: 'http://${device.host}:8161/admin',
      ),
      _WebLink(
        id: 'javamelody',
        title: 'JavaMelody',
        url: 'http://${device.host}:8080/monitoring',
      ),
      _WebLink(
        id: 'tomcat',
        title: 'Tomcat Manager',
        url: 'http://${device.host}:8080/manager/html',
      ),
      _WebLink(
        id: 'health',
        title: 'Health Check',
        url: 'http://${device.host}:8080/actuator/health',
      ),
    ];
  }

  Future<void> _openLink(String id, LinuxDevice device) async {
    final link = _links.firstWhere((item) => item.id == id);
    final url = _renderUrlWithAuth(link, device);
    _urlController.text = url;
    if (_webviewAvailable && Platform.isWindows) {
      await _controller.loadUrl(url);
    }
    if (!mounted) return;
    setState(() => _activeId = id);
  }

  String _renderUrl(String template, LinuxDevice device) {
    return template
        .replaceAll('{host}', device.host)
        .replaceAll('{port}', device.port.toString());
  }

  String _renderUrlWithAuth(_WebLink link, LinuxDevice device) {
    final base = _renderUrl(link.url, device);
    final password = _passwords[link.id];
    if ((link.username ?? '').isEmpty || (password ?? '').isEmpty) {
      return base;
    }
    final uri = Uri.tryParse(base);
    if (uri == null) return base;
    final withAuth = uri.replace(
      userInfo: '${link.username}:${password ?? ''}',
    );
    return withAuth.toString();
  }

  Future<void> _addLink(LinuxDevice device) async {
    final titleController = TextEditingController();
    final urlController = TextEditingController(text: 'http://{host}:8080/');
    final userController = TextEditingController();
    final passController = TextEditingController();

    final result = await showDialog<_WebLink>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая ссылка'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'http://{host}:8080/',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: userController,
              decoration: const InputDecoration(labelText: 'Логин (опционально)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passController,
              decoration: const InputDecoration(labelText: 'Пароль (опционально)'),
              obscureText: true,
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Поддерживаются {host} и {port}',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
              final url = urlController.text.trim();
              if (title.isEmpty || url.isEmpty) return;
              Navigator.pop(
                context,
                _WebLink(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  title: title,
                  url: url,
                  username: userController.text.trim(),
                ),
              );
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = [..._links, result];
    await prefs.setStringList(
      _linksKey(device.id),
      updated.map((e) => e.toStorage()).toList(),
    );
    if (passController.text.trim().isNotEmpty) {
      await _secureStorage.saveSecret(_passwordKey(result.id), passController.text.trim());
    }
    if (!mounted) return;
    setState(() {
      _links = updated;
      _passwords[result.id] = passController.text.trim();
    });
    _refreshHealth(device);
  }

  Future<void> _addTemplate(LinuxDevice device) async {
    final template = await showDialog<_WebTemplate>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Шаблоны'),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: _templates.map((item) {
              return ListTile(
                title: Text(item.title),
                subtitle: Text('http://{host}:${item.port}${item.path}'),
                onTap: () => Navigator.pop(context, item),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );

    if (template == null) return;

    final link = _WebLink(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: template.title,
      url: 'http://{host}:${template.port}${template.path}',
      username: '',
    );

    final prefs = await SharedPreferences.getInstance();
    final updated = [..._links, link];
    await prefs.setStringList(
      _linksKey(device.id),
      updated.map((e) => e.toStorage()).toList(),
    );
    if (!mounted) return;
    setState(() => _links = updated);
    _refreshHealth(device);
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      await _openExternalFallback(url);
    }
  }

  Future<void> _openExternalFallback(String url) async {
    try {
      if (Platform.isMacOS) {
        await Process.run('open', [url]);
      } else if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', url], runInShell: true);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
      }
    } catch (_) {}
  }

  Future<void> _editLink(LinuxDevice device, _WebLink link) async {
    final titleController = TextEditingController(text: link.title);
    final urlController = TextEditingController(text: link.url);
    final userController = TextEditingController(text: link.username ?? '');
    final passController = TextEditingController(text: _passwords[link.id] ?? '');

    final result = await showDialog<_WebLink>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать ссылку'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: userController,
              decoration: const InputDecoration(labelText: 'Логин'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: passController,
              decoration: const InputDecoration(labelText: 'Пароль'),
              obscureText: true,
            ),
            const SizedBox(height: 6),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Логин/пароль сохраняются локально.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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
              final url = urlController.text.trim();
              if (title.isEmpty || url.isEmpty) return;
              Navigator.pop(
                context,
                _WebLink(
                  id: link.id,
                  title: title,
                  url: url,
                  username: userController.text.trim(),
                ),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    final updated = _links.map((item) => item.id == link.id ? result : item).toList();
    await prefs.setStringList(
      _linksKey(device.id),
      updated.map((e) => e.toStorage()).toList(),
    );
    await _secureStorage.saveSecret(_passwordKey(link.id), passController.text);
    if (!mounted) return;
    setState(() {
      _links = updated;
      _passwords[link.id] = passController.text;
    });
    _refreshHealth(device);
  }

  Future<void> _removeLink(LinuxDevice device, _WebLink link) async {
    final prefs = await SharedPreferences.getInstance();
    final updated = _links.where((item) => item.id != link.id).toList();
    await prefs.setStringList(
      _linksKey(device.id),
      updated.map((e) => e.toStorage()).toList(),
    );
    await _secureStorage.deleteSecret(_passwordKey(link.id));
    if (!mounted) return;
    setState(() {
      _links = updated;
      if (_activeId == link.id) {
        _activeId = updated.isNotEmpty ? updated.first.id : null;
      }
    });
    if (updated.isNotEmpty) {
      await _openLink(updated.first.id, device);
    }
    _refreshHealth(device);
  }

  Future<void> _refreshHealth(LinuxDevice device) async {
    final results = <String, _LinkHealth>{};
    for (final link in _links) {
      final url = _renderUrl(link.url, device);
      results[link.id] = await _checkHealth(url, link);
    }
    if (!mounted) return;
    setState(() {
      _health.clear();
      _health.addAll(results);
    });
  }

  Future<_LinkHealth> _checkHealth(String url, _WebLink link) async {
    try {
      final uri = Uri.parse(url);
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(uri);
      final password = _passwords[link.id];
      if ((link.username ?? '').isNotEmpty && (password ?? '').isNotEmpty) {
        final auth = base64Encode(utf8.encode('${link.username}:${password ?? ''}'));
        request.headers.set(HttpHeaders.authorizationHeader, 'Basic $auth');
      }
      final response = await request.close().timeout(const Duration(seconds: 3));
      client.close();
      if (response.statusCode >= 200 && response.statusCode < 400) {
        return _LinkHealth.ok;
      }
      return _LinkHealth.fail;
    } catch (_) {
      return _LinkHealth.fail;
    }
  }

  Future<void> _openExternalForLink(LinuxDevice device, _WebLink link) async {
    final url = _renderUrlWithAuth(link, device);
    await _openExternal(url);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final device = context.watch<DeviceProvider>().selectedDevice;

    if (device == null) {
      return const Center(child: Text('Выберите сервер слева.'));
    }

    if (_deviceId != device.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadLinks();
      });
    }

    return Row(
      children: [
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              right: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
                child: Row(
                  children: [
                    Text(
                      'Ссылки',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => _addTemplate(device),
                      icon: const Icon(Icons.view_list),
                      tooltip: 'Шаблоны',
                    ),
                    IconButton(
                      onPressed: () => _addLink(device),
                      icon: const Icon(Icons.add),
                      tooltip: 'Добавить ссылку',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _links.length,
                  itemBuilder: (context, index) {
                    final link = _links[index];
                    final isActive = link.id == _activeId;
                    final health = _health[link.id];
                    return ListTile(
                      selected: isActive,
                      leading: Icon(_resolveIcon(link), size: 18),
                      title: Text(link.title),
                      subtitle: Text(
                        link.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _openLink(link.id, device),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (health != null)
                            Tooltip(
                              message: health == _LinkHealth.ok ? 'Доступно' : 'Недоступно',
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: health == _LinkHealth.ok
                                      ? Colors.green
                                      : Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _editLink(device, link);
                              } else if (value == 'remove') {
                                _removeLink(device, link);
                              } else if (value == 'external') {
                                _openExternalForLink(device, link);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Редактировать'),
                              ),
                              const PopupMenuItem(
                                value: 'external',
                                child: Text('Открыть во внешнем браузере'),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('Удалить'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(color: theme.dividerColor),
                  ),
                ),
                child: Row(
                  children: [
                    if (_webviewAvailable && Platform.isWindows) ...[
                      IconButton(
                        onPressed: () => _controller.goBack(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      IconButton(
                        onPressed: () => _controller.goForward(),
                        icon: const Icon(Icons.arrow_forward),
                      ),
                      IconButton(
                        onPressed: () => _controller.reload(),
                        icon: const Icon(Icons.refresh),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'URL',
                          isDense: true,
                        ),
                        onSubmitted: (value) {
                          if (_webviewAvailable && Platform.isWindows) {
                            _controller.loadUrl(value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_webviewAvailable && Platform.isWindows)
                      ElevatedButton(
                        onPressed: () => _controller.loadUrl(_urlController.text.trim()),
                        child: const Text('Открыть'),
                      ),
                    if (_webviewAvailable && Platform.isWindows)
                      const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () => _openExternal(_urlController.text.trim()),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('В браузер'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isReady
                    ? (_webviewAvailable && Platform.isWindows
                        ? Webview(_controller)
                        : _WebviewUnavailable(
                            onOpenExternal: () => _openExternal(_urlController.text.trim()),
                          ))
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _linksKey(String deviceId) => 'web_links_$deviceId';

class _WebLink {
  final String id;
  final String title;
  final String url;
  final String? username;

  const _WebLink({
    required this.id,
    required this.title,
    required this.url,
    this.username,
  });

  factory _WebLink.fromStorage(String raw) {
    final parts = raw.split('|');
    return _WebLink(
      id: parts.isNotEmpty ? parts[0] : DateTime.now().millisecondsSinceEpoch.toString(),
      title: parts.length > 1 ? parts[1] : 'Ссылка',
      url: parts.length > 2 ? parts[2] : '',
      username: parts.length > 3 ? parts[3] : '',
    );
  }

  String toStorage() => '$id|$title|$url|${username ?? ''}';
}

class _WebTemplate {
  final String title;
  final int port;
  final String path;

  const _WebTemplate({
    required this.title,
    required this.port,
    required this.path,
  });
}

const _templates = [
  _WebTemplate(title: 'ActiveMQ Console', port: 8161, path: '/admin'),
  _WebTemplate(title: 'JavaMelody', port: 8080, path: '/monitoring'),
  _WebTemplate(title: 'Tomcat Manager', port: 8080, path: '/manager/html'),
  _WebTemplate(title: 'Actuator Health', port: 8080, path: '/actuator/health'),
];

enum _LinkHealth { ok, fail }

IconData _resolveIcon(_WebLink link) {
  final title = link.title.toLowerCase();
  if (title.contains('activemq') || title.contains('mq')) {
    return Icons.queue;
  }
  if (title.contains('tomcat')) {
    return Icons.public;
  }
  if (title.contains('melody') || title.contains('monitor')) {
    return Icons.show_chart;
  }
  if (title.contains('health')) {
    return Icons.favorite;
  }
  return Icons.link;
}

String _passwordKey(String linkId) => 'web_link_${linkId}_password';

class _WebviewUnavailable extends StatelessWidget {
  final VoidCallback onOpenExternal;

  const _WebviewUnavailable({required this.onOpenExternal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public_off, size: 42, color: theme.hintColor),
              const SizedBox(height: 12),
              Text(
                'WebView2 не найден',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Откройте ссылку во внешнем браузере.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onOpenExternal,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Открыть во внешнем браузере'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
