import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/device_provider.dart';
import '../models/linux_device.dart';

class DeviceFormScreen extends StatefulWidget {
  final LinuxDevice? device;

  const DeviceFormScreen({super.key, this.device});

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '22');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _groupController = TextEditingController();
  bool _usePassword = true;
  bool _rememberCredentials = false;

  @override
  void initState() {
    super.initState();
    if (widget.device != null) {
      _nameController.text = widget.device!.name;
      _hostController.text = widget.device!.host;
      _portController.text = widget.device!.port.toString();
      _usernameController.text = widget.device!.username;
      _passwordController.text = widget.device!.password ?? '';
      _groupController.text = widget.device!.group ?? '';
      _usePassword = widget.device!.password != null;
      _rememberCredentials = widget.device!.rememberCredentials;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _groupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device == null ? 'Добавить устройство' : 'Редактировать устройство'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Название',
                hintText: 'Мой сервер',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите название';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Хост/IP',
                hintText: '192.168.1.100',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите хост или IP адрес';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                labelText: 'Порт',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите порт';
                }
                final port = int.tryParse(value);
                if (port == null || port < 1 || port > 65535) {
                  return 'Введите корректный порт';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Имя пользователя',
                hintText: 'root',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Введите имя пользователя';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _groupController,
              decoration: const InputDecoration(
                labelText: 'Группа',
                hintText: 'Прод / Тест / Бэкенд',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _usePassword,
                  onChanged: (value) {
                    setState(() {
                      _usePassword = value ?? true;
                    });
                  },
                ),
                const Text('Использовать пароль'),
              ],
            ),
            if (_usePassword)
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Пароль',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (_usePassword && (value == null || value.isEmpty)) {
                    return 'Введите пароль';
                  }
                  return null;
                },
              ),
            Row(
              children: [
                Checkbox(
                  value: _rememberCredentials,
                  onChanged: (value) {
                    setState(() {
                      _rememberCredentials = value ?? false;
                    });
                  },
                ),
                const Text('Сохранить пароль в безопасном хранилище'),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveDevice,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveDevice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final device = LinuxDevice(
      id: widget.device?.id ?? const Uuid().v4(),
      name: _nameController.text,
      host: _hostController.text,
      port: int.parse(_portController.text),
      username: _usernameController.text,
      password: _usePassword ? _passwordController.text : null,
      group: _groupController.text.trim().isEmpty ? null : _groupController.text.trim(),
      rememberCredentials: _rememberCredentials,
    );

    final provider = context.read<DeviceProvider>();
    if (widget.device == null) {
      await provider.addDevice(device);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Устройство "${device.name}" добавлено'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      await provider.updateDevice(device);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Устройство "${device.name}" обновлено'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    }

    if (context.mounted) {
      Navigator.pop(context);
    }
  }
}
