class LinuxDevice {
  final String id;
  final String name;
  final String host;
  final int port;
  final String username;
  final String? password;
  final String? privateKey;
  final String? group;
  final bool rememberCredentials;
  final bool isConnected;
  final DateTime? lastSeen;

  LinuxDevice({
    required this.id,
    required this.name,
    required this.host,
    this.port = 22,
    required this.username,
    this.password,
    this.privateKey,
    this.group,
    this.rememberCredentials = false,
    this.isConnected = false,
    this.lastSeen,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKey': privateKey,
      'group': group,
      'rememberCredentials': rememberCredentials,
      'isConnected': isConnected,
      'lastSeen': lastSeen?.toIso8601String(),
    };
  }

  factory LinuxDevice.fromJson(Map<String, dynamic> json) {
    return LinuxDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int? ?? 22,
      username: json['username'] as String,
      password: json['password'] as String?,
      privateKey: json['privateKey'] as String?,
      group: json['group'] as String?,
      rememberCredentials: json['rememberCredentials'] as bool? ?? false,
      isConnected: json['isConnected'] as bool? ?? false,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
    );
  }

  LinuxDevice copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? username,
    String? password,
    String? privateKey,
    String? group,
    bool? rememberCredentials,
    bool? isConnected,
    DateTime? lastSeen,
  }) {
    return LinuxDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKey: privateKey ?? this.privateKey,
      group: group ?? this.group,
      rememberCredentials: rememberCredentials ?? this.rememberCredentials,
      isConnected: isConnected ?? this.isConnected,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
