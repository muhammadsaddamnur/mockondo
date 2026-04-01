import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:mockondo/features/mock_s3/core/s3_server.dart';
import 'package:mockondo/features/mock_s3/data/models/s3_model.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/v4.dart';

class MockS3Controller extends GetxController {
  final config = const S3Config().obs;
  final buckets = <S3Bucket>[].obs;
  final objects = <S3Object>[].obs;
  final isRunning = false.obs;
  final serverError = RxnString();

  /// Device's current Wi-Fi IP (read-only, fetched on init).
  final ipAddress = ''.obs;

  // UI state
  final selectedBucket = RxnString();
  final currentPrefix = ''.obs;
  final isUploading = false.obs;

  // In-memory presigned token store (token → PresignedUrl)
  final _presignedTokens = <String, PresignedUrl>{};

  S3MockServer? _server;

  @override
  void onInit() {
    super.onInit();
    _load();
    _initServer();
    _fetchIp();
  }

  Future<void> _fetchIp() async {
    final ip = await NetworkInfo().getWifiIP();
    if (ip != null && ip.isNotEmpty) {
      ipAddress.value = ip;
      // Only update config host if it's still the factory default
      if (config.value.host == '127.0.0.1') {
        config.value = config.value.copyWith(host: ip);
      }
    }
  }

  @override
  void onClose() {
    _server?.stop();
    super.onClose();
  }

  void _initServer() {
    _server = S3MockServer(
      getBuckets: () => buckets,
      getObjects: () => objects,
      addObject: _serverAddObject,
      removeObject: _serverRemoveObject,
      readContent: _readContent,
      checkPresigned: _checkPresigned,
      onCreateBucket: createBucket,
    );
  }

  // ── Disk storage ──────────────────────────────────────────────────────────

  Future<Directory> _storageDir() async {
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    final dir = Directory('$home/.mockondo/s3');
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _objectFile(String bucket, String key) async {
    final base = await _storageDir();
    // key may contain '/' — reconstruct as OS path segments
    final parts = [base.path, bucket, ...key.split('/')];
    final file = File(parts.join(Platform.pathSeparator));
    await file.parent.create(recursive: true);
    return file;
  }

  // ── Server callbacks ──────────────────────────────────────────────────────

  Future<void> _serverAddObject(S3Object obj, List<int> bytes) async {
    dev.log('[S3] addObject bucket=${obj.bucket} key="${obj.key}" bytes=${bytes.length}', name: 'MockS3');
    if (bytes.isNotEmpty) {
      // Keys ending with '/' cannot map directly to a filesystem file path.
      // Append a sentinel filename so the content is preserved on disk.
      final diskKey =
          obj.key.endsWith('/') ? '${obj.key}.s3content' : obj.key;
      final file = await _objectFile(obj.bucket, diskKey);
      dev.log('[S3] writing to ${file.path}', name: 'MockS3');
      await file.writeAsBytes(bytes);
    }
    final idx = objects
        .indexWhere((o) => o.bucket == obj.bucket && o.key == obj.key);
    if (idx >= 0) {
      objects[idx] = obj;
    } else {
      objects.add(obj);
    }
    dev.log('[S3] objects count=${objects.length}', name: 'MockS3');
    objects.refresh();
    await _save();
  }

  Future<void> _serverRemoveObject(String bucket, String key) async {
    try {
      final diskKey = key.endsWith('/') ? '$key.s3content' : key;
      final file = await _objectFile(bucket, diskKey);
      if (await file.exists()) await file.delete();
    } catch (_) {}
    objects.removeWhere((o) => o.bucket == bucket && o.key == key);
    objects.refresh();
    await _save();
  }

  Future<List<int>?> _readContent(String bucket, String key) async {
    try {
      final diskKey = key.endsWith('/') ? '$key.s3content' : key;
      final file = await _objectFile(bucket, diskKey);
      if (await file.exists()) return await file.readAsBytes();
    } catch (_) {}
    return null;
  }

  bool _checkPresigned(
      String token, String bucket, String key, String method) {
    final p = _presignedTokens[token];
    if (p == null) return false;
    if (p.bucket != bucket || p.key != key) return false;
    if (p.operation.toUpperCase() != method.toUpperCase()) return false;
    if (p.isExpired) {
      _presignedTokens.remove(token);
      return false;
    }
    return true;
  }

  // ── Server lifecycle ──────────────────────────────────────────────────────

  Future<void> startServer() async {
    try {
      serverError.value = null;
      await _server?.start(config.value.host, config.value.port);
      isRunning.value = true;
    } catch (e) {
      serverError.value = e.toString();
    }
  }

  Future<void> stopServer() async {
    await _server?.stop();
    isRunning.value = false;
  }

  Future<void> restartServer() async {
    if (isRunning.value) await stopServer();
    await startServer();
  }

  // ── Bucket operations ─────────────────────────────────────────────────────

  void createBucket(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || buckets.any((b) => b.name == trimmed)) return;
    buckets.add(S3Bucket(name: trimmed, createdAt: DateTime.now().toUtc()));
    _save();
  }

  Future<void> deleteBucket(String name) async {
    // Remove all objects belonging to this bucket from disk and list
    final toDelete = objects.where((o) => o.bucket == name).toList();
    for (final obj in toDelete) {
      await _serverRemoveObject(obj.bucket, obj.key);
    }
    // Remove the bucket folder itself
    try {
      final dir = await _storageDir();
      final bucketDir =
          Directory('${dir.path}${Platform.pathSeparator}$name');
      if (await bucketDir.exists()) await bucketDir.delete(recursive: true);
    } catch (_) {}

    buckets.removeWhere((b) => b.name == name);
    if (selectedBucket.value == name) {
      selectedBucket.value = null;
      currentPrefix.value = '';
    }
    await _save();
  }

  void selectBucket(String name) {
    selectedBucket.value = name;
    currentPrefix.value = '';
  }

  // ── Object operations ─────────────────────────────────────────────────────

  /// Returns the items visible in the current bucket + prefix view.
  List<S3Item> getVisibleItems() {
    final bucket = selectedBucket.value;
    if (bucket == null) return [];
    final prefix = currentPrefix.value;
    final relevant = objects
        .where((o) => o.bucket == bucket && o.key.startsWith(prefix))
        .toList();

    final folders = <String>{};
    final files = <S3Object>[];

    for (final obj in relevant) {
      final after = obj.key.substring(prefix.length);
      if (after.isEmpty) continue;
      final slashIdx = after.indexOf('/');
      if (slashIdx >= 0) {
        folders.add(prefix + after.substring(0, slashIdx + 1));
      } else {
        files.add(obj);
      }
    }

    return [
      ...folders.map((f) => S3Item.folder(f)),
      ...files.map((o) => S3Item.object(o)),
    ];
  }

  void navigateToPrefix(String prefix) => currentPrefix.value = prefix;

  void navigateUp() {
    final p = currentPrefix.value;
    if (p.isEmpty) return;
    final trimmed = p.endsWith('/') ? p.substring(0, p.length - 1) : p;
    final idx = trimmed.lastIndexOf('/');
    currentPrefix.value = idx >= 0 ? trimmed.substring(0, idx + 1) : '';
  }

  Future<void> uploadFiles(String bucket, String prefix) async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (result == null || result.files.isEmpty) return;

    isUploading.value = true;
    try {
      for (final f in result.files) {
        if (f.path == null) continue;
        final bytes = await File(f.path!).readAsBytes();
        final key = '$prefix${f.name}';
        await _serverAddObject(
          S3Object(
            bucket: bucket,
            key: key,
            size: bytes.length,
            contentType: _mimeType(f.name),
            lastModified: DateTime.now().toUtc(),
            etag: _etag(bytes),
          ),
          bytes,
        );
      }
      objects.refresh();
    } finally {
      isUploading.value = false;
    }
  }

  Future<void> downloadObject(S3Object obj) async {
    final savePath = await FilePicker.platform.saveFile(
      fileName: obj.fileName,
      dialogTitle: 'Save ${obj.fileName}',
    );
    if (savePath == null) return;
    final bytes = await _readContent(obj.bucket, obj.key);
    if (bytes == null) return;
    await File(savePath).writeAsBytes(bytes);
  }

  Future<void> deleteObject(S3Object obj) async {
    await _serverRemoveObject(obj.bucket, obj.key);
    objects.refresh();
  }

  Future<void> deleteFolderPrefix(String bucket, String prefix) async {
    final toDelete = objects
        .where((o) => o.bucket == bucket && o.key.startsWith(prefix))
        .toList();
    for (final obj in toDelete) {
      await _serverRemoveObject(obj.bucket, obj.key);
    }
    objects.refresh();
  }

  Future<void> createFolder(
      String bucket, String prefix, String name) async {
    final safeName = name.replaceAll('/', '').trim();
    if (safeName.isEmpty) return;
    final key = '$prefix$safeName/';
    await _serverAddObject(
      S3Object(
        bucket: bucket,
        key: key,
        size: 0,
        contentType: 'application/x-directory',
        lastModified: DateTime.now().toUtc(),
        // Standard MD5 of empty string
        etag: 'd41d8cd98f00b204e9800998ecf8427e',
      ),
      [],
    );
    objects.refresh();
  }

  // ── Presigned URLs ────────────────────────────────────────────────────────

  PresignedUrl generatePresignedUrl({
    required String bucket,
    required String key,
    required String operation,
    required int expirySeconds,
  }) {
    final token = UuidV4().generate().replaceAll('-', '');
    final expiresAt = DateTime.now().add(Duration(seconds: expirySeconds));
    final c = config.value;
    final now = DateTime.now().toUtc();
    final date =
        '${now.year}${_pad(now.month)}${_pad(now.day)}';
    final dateTime =
        '${date}T${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}Z';

    final url = 'http://${c.host}:${c.port}/$bucket/$key'
        '?X-Amz-Algorithm=AWS4-HMAC-SHA256'
        '&X-Amz-Credential=${Uri.encodeComponent('${c.accessKey}/$date/${c.region}/s3/aws4_request')}'
        '&X-Amz-Date=$dateTime'
        '&X-Amz-Expires=$expirySeconds'
        '&X-Amz-SignedHeaders=host'
        '&X-Amz-Signature=$token';

    final result = PresignedUrl(
      url: url,
      operation: operation,
      bucket: bucket,
      key: key,
      expiresAt: expiresAt,
      token: token,
    );
    _presignedTokens[token] = result;
    return result;
  }

  // ── Config ────────────────────────────────────────────────────────────────

  void updateConfig(S3Config c) {
    config.value = c;
    _save();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _pad(int v) => v.toString().padLeft(2, '0');

  /// FNV-1a 32-bit hash used as a simple ETag for uploaded files.
  String _etag(List<int> bytes) {
    int h = 0x811C9DC5;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0').padLeft(32, '0');
  }

  String _mimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    const m = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp', 'svg': 'image/svg+xml',
      'pdf': 'application/pdf', 'json': 'application/json',
      'txt': 'text/plain', 'html': 'text/html', 'css': 'text/css',
      'js': 'application/javascript', 'ts': 'application/typescript',
      'xml': 'application/xml', 'zip': 'application/zip',
      'tar': 'application/x-tar', 'gz': 'application/gzip',
      'mp4': 'video/mp4', 'mp3': 'audio/mpeg', 'wav': 'audio/wav',
      'csv': 'text/csv', 'yaml': 'application/yaml',
      'yml': 'application/yaml', 'md': 'text/markdown',
    };
    return m[ext] ?? 'application/octet-stream';
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'mock_s3_config', jsonEncode(config.value.toJson()));
    await prefs.setString(
        'mock_s3_buckets',
        jsonEncode(buckets.map((b) => b.toJson()).toList()));
    await prefs.setString(
        'mock_s3_objects',
        jsonEncode(objects.map((o) => o.toJson()).toList()));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final cd = prefs.getString('mock_s3_config');
    if (cd != null) {
      try {
        config.value =
            S3Config.fromJson(jsonDecode(cd) as Map<String, dynamic>);
      } catch (_) {}
    }

    final bd = prefs.getString('mock_s3_buckets');
    if (bd != null) {
      try {
        buckets.value = (jsonDecode(bd) as List)
            .map((e) => S3Bucket.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final od = prefs.getString('mock_s3_objects');
    if (od != null) {
      try {
        objects.value = (jsonDecode(od) as List)
            .map((e) => S3Object.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
  }
}
