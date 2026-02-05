enum ServiceStatus {
  active,
  inactive,
  failed,
  activating,
  deactivating,
  unknown,
}

class Service {
  final String name;
  final String description;
  final ServiceStatus status;
  final bool isEnabled;
  final String? mainPid;

  Service({
    required this.name,
    required this.description,
    required this.status,
    required this.isEnabled,
    this.mainPid,
  });

  factory Service.fromJson(Map<String, dynamic> json) {
    return Service(
      name: json['name'] as String,
      description: json['description'] as String,
      status: parseStatus(json['status'] as String),
      isEnabled: json['isEnabled'] as bool,
      mainPid: json['mainPid'] as String?,
    );
  }

  static ServiceStatus parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'running':
        return ServiceStatus.active;
      case 'inactive':
      case 'stopped':
        return ServiceStatus.inactive;
      case 'failed':
        return ServiceStatus.failed;
      case 'activating':
        return ServiceStatus.activating;
      case 'deactivating':
        return ServiceStatus.deactivating;
      default:
        return ServiceStatus.unknown;
    }
  }

  String get statusText {
    switch (status) {
      case ServiceStatus.active:
        return 'Активна';
      case ServiceStatus.inactive:
        return 'Остановлена';
      case ServiceStatus.failed:
        return 'Ошибка';
      case ServiceStatus.activating:
        return 'Запускается';
      case ServiceStatus.deactivating:
        return 'Останавливается';
      case ServiceStatus.unknown:
        return 'Неизвестно';
    }
  }
}
