class FileItem {
  final String name;
  final String path;
  final bool isDirectory;
  final bool isSymlink;
  final int? size;
  final DateTime? modified;
  final String? permissions;
  final String? owner;
  final String? group;

  FileItem({
    required this.name,
    required this.path,
    required this.isDirectory,
    this.isSymlink = false,
    this.size,
    this.modified,
    this.permissions,
    this.owner,
    this.group,
  });

  factory FileItem.fromJson(Map<String, dynamic> json) {
    return FileItem(
      name: json['name'] as String,
      path: json['path'] as String,
      isDirectory: json['isDirectory'] as bool,
      isSymlink: json['isSymlink'] as bool? ?? false,
      size: json['size'] as int?,
      modified: json['modified'] != null
          ? DateTime.parse(json['modified'] as String)
          : null,
      permissions: json['permissions'] as String?,
      owner: json['owner'] as String?,
      group: json['group'] as String?,
    );
  }

  String get sizeFormatted {
    if (size == null) return '-';
    if (size! < 1024) return '$size B';
    if (size! < 1024 * 1024) return '${(size! / 1024).toStringAsFixed(2)} KB';
    if (size! < 1024 * 1024 * 1024) {
      return '${(size! / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(size! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
