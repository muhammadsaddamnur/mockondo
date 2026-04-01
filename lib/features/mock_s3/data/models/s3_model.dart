class S3Config {
  final String host;
  final int port;
  final String accessKey;
  final String secretKey;
  final String region;

  const S3Config({
    this.host = '127.0.0.1',
    this.port = 9000,
    this.accessKey = 'mockondo',
    this.secretKey = 'mockondo123',
    this.region = 'us-east-1',
  });

  S3Config copyWith({
    String? host,
    int? port,
    String? accessKey,
    String? secretKey,
    String? region,
  }) =>
      S3Config(
        host: host ?? this.host,
        port: port ?? this.port,
        accessKey: accessKey ?? this.accessKey,
        secretKey: secretKey ?? this.secretKey,
        region: region ?? this.region,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'accessKey': accessKey,
        'secretKey': secretKey,
        'region': region,
      };

  factory S3Config.fromJson(Map<String, dynamic> json) => S3Config(
        host: (json['host'] as String?) ?? '127.0.0.1',
        port: (json['port'] as int?) ?? 9000,
        accessKey: (json['accessKey'] as String?) ?? 'mockondo',
        secretKey: (json['secretKey'] as String?) ?? 'mockondo123',
        region: (json['region'] as String?) ?? 'us-east-1',
      );
}

class S3Bucket {
  final String name;
  final DateTime createdAt;

  const S3Bucket({required this.name, required this.createdAt});

  Map<String, dynamic> toJson() => {
        'name': name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory S3Bucket.fromJson(Map<String, dynamic> json) => S3Bucket(
        name: json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class S3Object {
  final String bucket;
  final String key;
  final int size;
  final String contentType;
  final DateTime lastModified;
  final String etag;

  const S3Object({
    required this.bucket,
    required this.key,
    required this.size,
    required this.contentType,
    required this.lastModified,
    required this.etag,
  });

  String get fileName {
    final k = key.endsWith('/') ? key.substring(0, key.length - 1) : key;
    return k.contains('/') ? k.split('/').last : k;
  }

  Map<String, dynamic> toJson() => {
        'bucket': bucket,
        'key': key,
        'size': size,
        'contentType': contentType,
        'lastModified': lastModified.toIso8601String(),
        'etag': etag,
      };

  factory S3Object.fromJson(Map<String, dynamic> json) => S3Object(
        bucket: json['bucket'] as String,
        key: json['key'] as String,
        size: (json['size'] as int?) ?? 0,
        contentType:
            (json['contentType'] as String?) ?? 'application/octet-stream',
        lastModified: DateTime.parse(json['lastModified'] as String),
        etag: (json['etag'] as String?) ?? '',
      );
}

class PresignedUrl {
  final String url;
  final String operation; // 'GET' or 'PUT'
  final String bucket;
  final String key;
  final DateTime expiresAt;
  final String token;

  const PresignedUrl({
    required this.url,
    required this.operation,
    required this.bucket,
    required this.key,
    required this.expiresAt,
    required this.token,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// UI list item — either a virtual folder prefix or a real S3 object.
class S3Item {
  final bool isFolder;
  final String folderPrefix; // set when isFolder == true
  final S3Object? object; // set when isFolder == false

  const S3Item.folder(this.folderPrefix)
      : isFolder = true,
        object = null;

  const S3Item.object(S3Object obj)
      : isFolder = false,
        object = obj,
        folderPrefix = '';

  String get displayName {
    if (isFolder) {
      final p = folderPrefix.endsWith('/')
          ? folderPrefix.substring(0, folderPrefix.length - 1)
          : folderPrefix;
      return '${p.split('/').last}/';
    }
    return object!.fileName;
  }
}
