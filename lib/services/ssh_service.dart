import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../models/linux_device.dart';
import '../models/system_stats.dart';
import '../models/file_item.dart';
import '../models/service.dart';

class SshService {
  SSHClient? _client;
  LinuxDevice? _currentDevice;
  List<int>? _lastCpuSample;
  SftpClient? _sftpClient;

  // ================= CONNECT =================

  Future<bool> connect(LinuxDevice device) async {
    await disconnect();

    final socket = await SSHSocket.connect(
      device.host,
      device.port,
      timeout: const Duration(seconds: 4),
    );

    _client = SSHClient(
      socket,
      username: device.username,
      onPasswordRequest: () => device.password ?? '',
    );

    _currentDevice = device;

    final test = await executeCommand('echo connected');
    return test.trim() == 'connected';
  }


  Future<void> disconnect() async {
    try {
      _client?.close();
    } catch (_) {}
    _sftpClient = null;
    _client = null;
    _currentDevice = null;
  }

  bool get isConnected => _client != null;
  LinuxDevice? get currentDevice => _currentDevice;

  // ================= EXEC =================

  Future<String> executeCommand(String command) async {
    if (_client == null) {
      throw Exception('Not connected');
    }

    final session = await _client!.execute(command);

    final out = StringBuffer();
    final err = StringBuffer();

    await for (final data in session.stdout) {
      out.write(utf8.decode(data));
    }

    await for (final data in session.stderr) {
      err.write(utf8.decode(data));
    }

    final code = session.exitCode;

    if (code != 0 && err.isNotEmpty) {
      throw Exception(err.toString());
    }

    return out.toString();
  }

  Future<String> executeCommandInDir(String directory, String command) async {
    final escaped = _escapePath(directory);
    return executeCommand("cd '$escaped' && $command");
  }

  Future<SftpClient> _sftp() async {
    if (_client == null) {
      throw Exception('Not connected');
    }
    _sftpClient ??= await _client!.sftp();
    return _sftpClient!;
  }

  Future<String> getHomeDirectory() async {
    try {
      final home = await executeCommand("echo \$HOME");
      final trimmed = home.trim();
      return trimmed.isEmpty ? '/' : trimmed;
    } catch (_) {
      return '/';
    }
  }

  // ================= SYSTEM =================

  Future<SystemStats> getSystemStats() async {
    try {
      final cpuUsage = await _readCpuUsage();

      final memInfo =
          await executeCommand("awk '/MemTotal|MemAvailable/ {print \$2}' /proc/meminfo");
      final memLines = memInfo.trim().split(RegExp(r'\s+'));
      final memTotalKb = memLines.isNotEmpty ? double.tryParse(memLines[0]) ?? 0.0 : 0.0;
      final memAvailKb = memLines.length > 1 ? double.tryParse(memLines[1]) ?? 0.0 : 0.0;
      final memUsedKb = (memTotalKb - memAvailKb).clamp(0, double.infinity);
      final memUsage = memTotalKb == 0 ? 0.0 : memUsedKb * 100.0 / memTotalKb;

      final swapInfo =
          await executeCommand("awk '/SwapTotal|SwapFree/ {print \$2}' /proc/meminfo");
      final swapLines = swapInfo.trim().split(RegExp(r'\s+'));
      final swapTotalKb =
          swapLines.isNotEmpty ? double.tryParse(swapLines[0]) ?? 0.0 : 0.0;
      final swapFreeKb =
          swapLines.length > 1 ? double.tryParse(swapLines[1]) ?? 0.0 : 0.0;
      final swapUsedKb = (swapTotalKb - swapFreeKb).clamp(0, double.infinity);
      final swapUsage = swapTotalKb == 0 ? 0.0 : swapUsedKb * 100.0 / swapTotalKb;

      final diskRaw = await executeCommand("df -B1 / | tail -1 | awk '{print \$2,\$3}'");
      final diskParts = diskRaw.trim().split(RegExp(r'\s+'));
      final diskTotalBytes = diskParts.isNotEmpty ? double.tryParse(diskParts[0]) ?? 0.0 : 0.0;
      final diskUsedBytes =
          diskParts.length > 1 ? double.tryParse(diskParts[1]) ?? 0.0 : 0.0;
      final diskUsage = diskTotalBytes == 0 ? 0.0 : diskUsedBytes * 100.0 / diskTotalBytes;

      final netRaw = await executeCommand(
        "cat /proc/net/dev | awk 'NR>2 {rx+=\$2; tx+=\$10} END {print rx, tx}'",
      );
      final netParts = netRaw.trim().split(RegExp(r'\s+'));
      final netRx = netParts.isNotEmpty ? double.tryParse(netParts[0]) ?? 0.0 : 0.0;
      final netTx = netParts.length > 1 ? double.tryParse(netParts[1]) ?? 0.0 : 0.0;

      final uptimeRaw = (await executeCommand("cat /proc/uptime")).trim();
      final uptimeSeconds = double.tryParse(uptimeRaw.split(' ').first) ?? 0.0;

      final processes = int.tryParse(
            (await executeCommand("ls -1 /proc | grep -E '^[0-9]+' | wc -l"))
                .trim(),
          ) ??
          0;

      final loadRaw = (await executeCommand("cat /proc/loadavg")).trim();
      final loadParts = loadRaw.split(RegExp(r'\s+'));

      final hostname = (await executeCommand("hostname")).trim();
      final kernel = (await executeCommand("uname -r")).trim();
      final osName = (await executeCommand("cat /etc/os-release | grep '^PRETTY_NAME=' | cut -d= -f2 | tr -d '\"'"))
          .trim();

      final servicesRaw = await executeCommand(
        "systemctl list-units --type=service --no-legend --no-pager 2>/dev/null | awk '{print \$3}'",
      );
      int active = 0;
      int inactive = 0;
      int failed = 0;
      for (final line in servicesRaw.split('\n')) {
        switch (line.trim()) {
          case 'active':
            active += 1;
            break;
          case 'inactive':
            inactive += 1;
            break;
          case 'failed':
            failed += 1;
            break;
          default:
            break;
        }
      }

      return SystemStats(
        cpuUsage: cpuUsage,
        memoryUsage: memUsage,
        memoryTotal: memTotalKb * 1024,
        memoryUsed: memUsedKb * 1024,
        diskUsage: diskUsage,
        diskTotal: diskTotalBytes,
        diskUsed: diskUsedBytes,
        swapUsage: swapUsage,
        swapTotal: swapTotalKb * 1024,
        swapUsed: swapUsedKb * 1024,
        netRxBytes: netRx,
        netTxBytes: netTx,
        hostname: hostname,
        kernel: kernel,
        osName: osName,
        uptime: _formatUptime(uptimeSeconds),
        processes: processes,
        servicesActive: active,
        servicesFailed: failed,
        servicesInactive: inactive,
        loadAverage1: loadParts.isNotEmpty ? double.tryParse(loadParts[0]) ?? 0 : 0,
        loadAverage5: loadParts.length > 1 ? double.tryParse(loadParts[1]) ?? 0 : 0,
        loadAverage15: loadParts.length > 2 ? double.tryParse(loadParts[2]) ?? 0 : 0,
      );
    } catch (_) {
      return _getSimpleSystemStats();
    }
  }

  Future<SystemStats> _getSimpleSystemStats() async {
    return SystemStats(
      cpuUsage:
      double.tryParse((await executeCommand("top -bn1 | awk '{print \$2}'"))
          .trim()) ??
          0.0,
      memoryUsage: double.tryParse(
          (await executeCommand("free | awk 'NR==2{print \$3/\$2*100}'"))
              .trim()) ??
          0.0,
      memoryTotal: 0,
      memoryUsed: 0,
      diskUsage: double.tryParse(
          (await executeCommand(
              "df / | tail -1 | awk '{print \$5}' | sed 's/%//'"))
              .trim()) ??
          0.0,
      diskTotal: 0,
      diskUsed: 0,
      swapUsage: 0,
      swapTotal: 0,
      swapUsed: 0,
      netRxBytes: 0,
      netTxBytes: 0,
      hostname: '',
      kernel: '',
      osName: '',
      uptime: (await executeCommand("uptime")).trim(),
      processes:
      int.tryParse((await executeCommand("ps aux | wc -l")).trim()) ?? 0,
      servicesActive: 0,
      servicesFailed: 0,
      servicesInactive: 0,
      loadAverage1: 0,
      loadAverage5: 0,
      loadAverage15: 0,
    );
  }

  Future<double> _readCpuUsage() async {
    final output = await executeCommand("cat /proc/stat; sleep 0.2; cat /proc/stat");
    final lines = output.split('\n');
    final samples = <List<int>>[];

    for (final line in lines) {
      if (line.startsWith('cpu ')) {
        final parts = line.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
        if (parts.length >= 8) {
          samples.add(
            parts
                .sublist(1, 8)
                .map((v) => int.tryParse(v) ?? 0)
                .toList(),
          );
        }
      }
    }

    if (samples.length < 2) {
      if (_lastCpuSample == null && samples.isNotEmpty) {
        _lastCpuSample = samples.last;
      }
      return 0.0;
    }

    final first = samples[samples.length - 2];
    final second = samples.last;
    _lastCpuSample = second;

    final total1 = first.fold<int>(0, (sum, v) => sum + v);
    final total2 = second.fold<int>(0, (sum, v) => sum + v);
    final idle1 = first[3] + first[4];
    final idle2 = second[3] + second[4];

    final totalDelta = total2 - total1;
    final idleDelta = idle2 - idle1;

    if (totalDelta <= 0) return 0.0;
    return (1 - idleDelta / totalDelta) * 100.0;
  }

  String _formatUptime(double seconds) {
    final totalSeconds = seconds.floor();
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;

    final parts = <String>[];
    if (days > 0) parts.add('$daysд');
    if (hours > 0) parts.add('$hoursч');
    if (minutes > 0) parts.add('$minutesм');
    if (parts.isEmpty) parts.add('${totalSeconds}s');
    return parts.join(' ');
  }

  // ================= FILES =================

  Future<List<FileItem>> listFiles(String path) async {
    try {
      final filesByLsLong = await _listFilesWithLsLong(path);
      if (filesByLsLong.isNotEmpty) return filesByLsLong;

      final files = await _listFilesWithStat(path);
      if (files.isNotEmpty) return files;

      final filesByFind = await _listFilesWithFind(path);
      if (filesByFind.isNotEmpty) return filesByFind;

      final hasEntries = (await executeCommand("ls -A '${_escapePath(path)}' 2>/dev/null"))
          .trim()
          .isNotEmpty;
      if (!hasEntries) return [];

      return _listFilesWithLs(path);
    } catch (_) {
      return _listFilesWithLs(path);
    }
  }


  String _escapePath(String path) {
    return path.replaceAll("'", "'\"'\"'");
  }

  Future<List<FileItem>> _listFilesWithFind(String path) async {
    final escaped = _escapePath(path);
    final result = await executeCommand(
      "find '$escaped' -maxdepth 1 -mindepth 1 -printf '%y\\x1F%s\\x1F%p\\x1F%f\\x1F%u\\x1F%g\\x1F%M\\x1F%TY-%Tm-%TdT%TH:%TM:%TS\\0' 2>/dev/null",
    );

    final files = <FileItem>[];
    final entries = result.split('\u0000');

    for (final entry in entries) {
      if (entry.trim().isEmpty) continue;
      final parts = entry.split('\x1F');
      if (parts.length < 8) continue;

      final type = parts[0];
      final size = int.tryParse(parts[1]);
      final fullPath = parts[2];
      final name = parts[3];
      final owner = parts[4];
      final group = parts[5];
      final perms = parts[6];
      final modifiedRaw = parts[7];

      DateTime? modified;
      try {
        final cleaned = modifiedRaw.split('.').first;
        modified = DateTime.tryParse(cleaned);
      } catch (_) {}

      files.add(
        FileItem(
          name: name,
          path: fullPath,
          isDirectory: type == 'd',
          isSymlink: type == 'l',
          size: size,
          permissions: perms,
          owner: owner,
          group: group,
          modified: modified,
        ),
      );
    }

    return files;
  }

  Future<List<FileItem>> _listFilesWithStat(String path) async {
    final escaped = _escapePath(path);
    final scriptLinux =
        "find '$escaped' -maxdepth 1 -mindepth 1 -print 2>/dev/null | "
        "while IFS= read -r f; do "
        "stat -c '%F|%s|%n|%U|%G|%A|%y' -- \"\\\$f\" 2>/dev/null || true; "
        "done; true";
    final scriptBsd =
        "find '$escaped' -maxdepth 1 -mindepth 1 -print 2>/dev/null | "
        "while IFS= read -r f; do "
        "stat -f '%HT|%z|%N|%Su|%Sg|%Sp|%Sm' -- \"\\\$f\" 2>/dev/null || true; "
        "done; true";

    String result = '';
    try {
      result = await executeCommand("sh -c \"$scriptLinux\"");
      if (result.trim().isEmpty) {
        result = await executeCommand("sh -c \"$scriptBsd\"");
      }
    } catch (_) {
      try {
        result = await executeCommand("sh -c \"$scriptBsd\"");
      } catch (_) {
        return [];
      }
    }

    if (result.trim().isEmpty) return [];

    final files = <FileItem>[];
    final entries = result.contains('\u0000') ? result.split('\u0000') : result.split('\n');

    for (final entry in entries) {
      if (entry.trim().isEmpty) continue;
      final parts = entry.split('|');
      if (parts.length < 7) continue;

      final type = parts[0].toLowerCase();
      final size = int.tryParse(parts[1]);
      final fullPath = parts[2];
      final owner = parts[3];
      final group = parts[4];
      final perms = parts[5];
      final modifiedRaw = parts[6];

      final name = fullPath.split('/').isNotEmpty ? fullPath.split('/').last : fullPath;
      if (name == '.' || name == '..') continue;

      DateTime? modified;
      try {
        final cleaned = modifiedRaw.split('.').first;
        modified = DateTime.tryParse(cleaned);
      } catch (_) {}

      final isDir = type.contains('directory');
      final isSymlink = type.contains('symbolic link');

      files.add(
        FileItem(
          name: name,
          path: fullPath,
          isDirectory: isDir,
          isSymlink: isSymlink,
          size: size,
          permissions: perms,
          owner: owner,
          group: group,
          modified: modified,
        ),
      );
    }

    return files;
  }

  Future<List<FileItem>> _listFilesWithLsLong(String path) async {
    final escaped = _escapePath(path);
    final prefix = path == '/' ? '' : escaped;
    final script =
        "ls -1A -- '$escaped' 2>/dev/null | "
        "while IFS= read -r n; do "
        "p=\"$prefix/\\\$n\"; "
        "ls -ld -- \"\\\$p\" 2>/dev/null || echo \"? \\\$n\"; "
        "done";

    String result = '';
    try {
      result = await executeCommand("sh -c \"$script\"");
    } catch (_) {
      return [];
    }

    if (result.trim().isEmpty) return [];

    final files = <FileItem>[];
    for (final line in result.split('\n')) {
      if (line.trim().isEmpty) continue;
      if (line.startsWith('? ')) {
        final name = line.substring(2).trim();
        if (name.isEmpty || name == '.' || name == '..') continue;
        files.add(
          FileItem(
            name: name,
            path: path == '/' ? '/$name' : '$path/$name',
            isDirectory: false,
            isSymlink: false,
            size: null,
            permissions: null,
            owner: null,
            group: null,
            modified: null,
          ),
        );
        continue;
      }

      final match = RegExp(
        r'^([\-ldcbps][rwxstST-]{9})\s+\d+\s+(\S+)\s+(\S+)\s+(\d+)\s+(\w+)\s+(\d+)\s+([\d:]{4,5}|\d{4})\s+(.+)$',
      ).firstMatch(line);

      if (match == null) continue;

      final perms = match.group(1)!;
      final owner = match.group(2)!;
      final group = match.group(3)!;
      final size = int.tryParse(match.group(4)!);
      final month = match.group(5)!;
      final day = match.group(6)!;
      final timeOrYear = match.group(7)!;
      final namePart = match.group(8)!;

      final name = namePart.split(' -> ').first;
      if (name == '.' || name == '..') continue;

      DateTime? modified;
      try {
        final year = timeOrYear.contains(':')
            ? DateTime.now().year.toString()
            : timeOrYear;
        final time = timeOrYear.contains(':') ? timeOrYear : '00:00';
        final monthNum = _monthToNumber(month);
        if (monthNum != null) {
          modified = DateTime.tryParse(
            '$year-$monthNum-${day.padLeft(2, '0')}T$time:00',
          );
        }
      } catch (_) {}

      files.add(
        FileItem(
          name: name,
          path: path == '/' ? '/$name' : '$path/$name',
          isDirectory: perms.startsWith('d'),
          isSymlink: perms.startsWith('l'),
          size: size,
          permissions: perms,
          owner: owner,
          group: group,
          modified: modified,
        ),
      );
    }

    return files;
  }

  String? _monthToNumber(String month) {
    const months = {
      'Jan': '01',
      'Feb': '02',
      'Mar': '03',
      'Apr': '04',
      'May': '05',
      'Jun': '06',
      'Jul': '07',
      'Aug': '08',
      'Sep': '09',
      'Oct': '10',
      'Nov': '11',
      'Dec': '12',
    };
    return months[month];
  }

  Future<List<FileItem>> _listFilesWithLs(String path) async {
    final escaped = _escapePath(path);
    String result;
    try {
      result = await executeCommand(
        "ls -la --time-style=+%Y-%m-%dT%H:%M:%S '$escaped' 2>/dev/null | tail -n +2",
      );
    } catch (_) {
      result = await executeCommand("ls -la '$escaped' 2>/dev/null | tail -n +2");
    }

    final files = <FileItem>[];

    for (final line in result.split('\n')) {
      if (line.trim().isEmpty) continue;
      if (line.startsWith('total')) continue;

      final match = RegExp(r'^([\-ldcbps][rwxstST-]{9})\s+\d+\s+(\S+)\s+(\S+)\s+(\d+)\s+(.+)$')
          .firstMatch(line);
      if (match == null) continue;

      final perms = match.group(1)!;
      final owner = match.group(2)!;
      final group = match.group(3)!;
      final size = int.tryParse(match.group(4)!);
      final remainder = match.group(5)!;

      final remParts = remainder.split(RegExp(r'\s+'));
      if (remParts.isEmpty) continue;

      String name;
      DateTime? modified;

      if (remParts.first.contains('T')) {
        final timeToken = remParts.first;
        name = remParts.sublist(1).join(' ');
        modified = DateTime.tryParse(timeToken);
      } else {
        if (remParts.length < 4) continue;
        name = remParts.sublist(3).join(' ');
      }

      if (name == '.' || name == '..') continue;

      files.add(
        FileItem(
          name: name,
          path: path == '/' ? '/$name' : '$path/$name',
          isDirectory: perms.startsWith('d'),
          isSymlink: perms.startsWith('l'),
          size: size,
          permissions: perms,
          owner: owner,
          group: group,
          modified: modified,
        ),
      );
    }

    return files;
  }

  Future<void> deletePath(String path) async {
    final escaped = _escapePath(path);
    await executeCommand("rm -rf -- '$escaped'");
  }

  Future<void> createFile(String path) async {
    final escaped = _escapePath(path);
    await executeCommand("touch -- '$escaped'");
  }

  Future<String> readFile(String path) async {
    final escaped = _escapePath(path);
    final encoded = await executeCommand(
      "base64 -w0 -- '$escaped' 2>/dev/null || base64 -- '$escaped' | tr -d '\\n'",
    );
    return utf8.decode(base64.decode(encoded));
  }

  Future<void> writeFile(String path, String content) async {
    final escaped = _escapePath(path);
    final encoded = base64.encode(utf8.encode(content));
    await executeCommand("printf '%s' '$encoded' | base64 -d > '$escaped'");
  }

  Future<void> uploadFile(String localPath, String remotePath) async {
    final sftp = await _sftp();
    final file = File(localPath);
    if (!await file.exists()) {
      throw Exception('Локальный файл не найден');
    }
    final bytes = await file.readAsBytes();
    final remote = await sftp.open(
      remotePath,
      mode: SftpFileOpenMode.create | SftpFileOpenMode.write | SftpFileOpenMode.truncate,
    );
    await remote.writeBytes(bytes);
    await remote.close();
  }

  Future<void> downloadFile(String remotePath, String localPath) async {
    final sftp = await _sftp();
    final remote = await sftp.open(remotePath, mode: SftpFileOpenMode.read);
    final bytes = await remote.readBytes();
    await remote.close();
    final file = File(localPath);
    await file.writeAsBytes(bytes, flush: true);
  }

  Future<List<String>> listMatchingPaths(String pattern) async {
    final escaped = _escapePath(pattern);
    final cmd = "ls -1 $escaped 2>/dev/null";
    final result = await executeCommand(cmd);
    return result
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<List<int>> readFileBytes(String path) async {
    final sftp = await _sftp();
    final remote = await sftp.open(path, mode: SftpFileOpenMode.read);
    final bytes = await remote.readBytes();
    await remote.close();
    return bytes;
  }

  Future<void> chmodPath(String path, String mode) async {
    final escaped = _escapePath(path);
    await executeCommand("chmod $mode -- '$escaped'");
  }

  Future<void> createDirectory(String path) async {
    final escaped = _escapePath(path);
    await executeCommand("mkdir -p -- '$escaped'");
  }

  Future<void> renamePath(String oldPath, String newPath) async {
    final escapedOld = _escapePath(oldPath);
    final escapedNew = _escapePath(newPath);
    await executeCommand("mv -- '$escapedOld' '$escapedNew'");
  }

  Future<void> copyPath(String source, String destination) async {
    final escapedSource = _escapePath(source);
    final escapedDestination = _escapePath(destination);
    await executeCommand("cp -a -- '$escapedSource' '$escapedDestination'");
  }

  // ================= SERVICES =================

  Future<List<Service>> getServices() async {
    final result = await executeCommand(
      "systemctl list-units --type=service --no-legend --no-pager | awk '{print \$1,\$3,\$4}'",
    );

    final services = <Service>[];

    for (final line in result.split('\n')) {
      if (line.trim().isEmpty) continue;

      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 3) continue;

      final name = parts[0];
      final status = parts[1];
      final desc = parts.sublist(2).join(' ');

      final enabled = (await executeCommand(
        "systemctl is-enabled $name 2>/dev/null || echo disabled",
      ))
          .trim() ==
          'enabled';

      services.add(
        Service(
          name: name,
          description: desc,
          status: Service.parseStatus(status),
          isEnabled: enabled,
        ),
      );
    }

    return services;
  }

  Future<bool> startService(String s) async {
    await executeCommand("sudo systemctl start $s");
    return true;
  }

  Future<bool> stopService(String s) async {
    await executeCommand("sudo systemctl stop $s");
    return true;
  }

  Future<bool> restartService(String s) async {
    await executeCommand("sudo systemctl restart $s");
    return true;
  }

  Future<bool> enableService(String s) async {
    await executeCommand("sudo systemctl enable $s");
    return true;
  }

  Future<bool> disableService(String s) async {
    await executeCommand("sudo systemctl disable $s");
    return true;
  }

  Future<String> getServiceLogs(String serviceName, {int lines = 200}) async {
    final escaped = _escapePath(serviceName);
    return executeCommand(
      "journalctl -u '$escaped' -n $lines --no-pager --output=short-iso 2>/dev/null || echo 'Логи недоступны'",
    );
  }

  Future<String> getCrontab() async {
    return executeCommand("crontab -l 2>/dev/null || true");
  }

  Future<void> setCrontab(String content) async {
    final encoded = base64.encode(utf8.encode(content));
    await executeCommand("printf '%s' '$encoded' | base64 -d | crontab -");
  }
}
