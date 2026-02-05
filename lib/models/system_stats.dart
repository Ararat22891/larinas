class SystemStats {
  final double cpuUsage;
  final double memoryUsage;
  final double memoryTotal;
  final double memoryUsed;
  final double diskUsage;
  final double diskTotal;
  final double diskUsed;
  final double swapUsage;
  final double swapTotal;
  final double swapUsed;
  final double netRxBytes;
  final double netTxBytes;
  final String hostname;
  final String kernel;
  final String osName;
  final String uptime;
  final int processes;
  final int servicesActive;
  final int servicesFailed;
  final int servicesInactive;
  final double loadAverage1;
  final double loadAverage5;
  final double loadAverage15;

  SystemStats({
    required this.cpuUsage,
    required this.memoryUsage,
    required this.memoryTotal,
    required this.memoryUsed,
    required this.diskUsage,
    required this.diskTotal,
    required this.diskUsed,
    required this.swapUsage,
    required this.swapTotal,
    required this.swapUsed,
    required this.netRxBytes,
    required this.netTxBytes,
    required this.hostname,
    required this.kernel,
    required this.osName,
    required this.uptime,
    required this.processes,
    required this.servicesActive,
    required this.servicesFailed,
    required this.servicesInactive,
    required this.loadAverage1,
    required this.loadAverage5,
    required this.loadAverage15,
  });

  factory SystemStats.fromJson(Map<String, dynamic> json) {
    return SystemStats(
      cpuUsage: (json['cpuUsage'] as num).toDouble(),
      memoryUsage: (json['memoryUsage'] as num).toDouble(),
      memoryTotal: (json['memoryTotal'] as num).toDouble(),
      memoryUsed: (json['memoryUsed'] as num).toDouble(),
      diskUsage: (json['diskUsage'] as num).toDouble(),
      diskTotal: (json['diskTotal'] as num).toDouble(),
      diskUsed: (json['diskUsed'] as num).toDouble(),
      swapUsage: (json['swapUsage'] as num).toDouble(),
      swapTotal: (json['swapTotal'] as num).toDouble(),
      swapUsed: (json['swapUsed'] as num).toDouble(),
      netRxBytes: (json['netRxBytes'] as num).toDouble(),
      netTxBytes: (json['netTxBytes'] as num).toDouble(),
      hostname: json['hostname'] as String? ?? '',
      kernel: json['kernel'] as String? ?? '',
      osName: json['osName'] as String? ?? '',
      uptime: json['uptime'] as String,
      processes: json['processes'] as int,
      servicesActive: json['servicesActive'] as int? ?? 0,
      servicesFailed: json['servicesFailed'] as int? ?? 0,
      servicesInactive: json['servicesInactive'] as int? ?? 0,
      loadAverage1: (json['loadAverage1'] as num).toDouble(),
      loadAverage5: (json['loadAverage5'] as num).toDouble(),
      loadAverage15: (json['loadAverage15'] as num).toDouble(),
    );
  }
}
