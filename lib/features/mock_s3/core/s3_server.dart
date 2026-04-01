import 'dart:developer' as dev;
import 'dart:io';

import 'package:mockondo/features/mock_s3/data/models/s3_model.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Shelf-based S3-compatible mock server.
///
/// All bucket/object state is managed by the controller and accessed via
/// callbacks so this class stays free of any GetX dependency.
class S3MockServer {
  final List<S3Bucket> Function() getBuckets;
  final List<S3Object> Function() getObjects;
  final Future<void> Function(S3Object obj, List<int> bytes) addObject;
  final Future<void> Function(String bucket, String key) removeObject;
  final Future<List<int>?> Function(String bucket, String key) readContent;
  final bool Function(String token, String bucket, String key, String method)
      checkPresigned;
  final void Function(String name) onCreateBucket;

  HttpServer? _server;

  S3MockServer({
    required this.getBuckets,
    required this.getObjects,
    required this.addObject,
    required this.removeObject,
    required this.readContent,
    required this.checkPresigned,
    required this.onCreateBucket,
  });

  bool get isRunning => _server != null;

  Future<void> start(String host, int port) async {
    final handler =
        const Pipeline().addMiddleware(_cors()).addHandler(_handle);
    // Bind to all interfaces so the server is reachable regardless of which
    // network interface the configured host belongs to.
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  // ── CORS middleware ──────────────────────────────────────────────────────

  Middleware _cors() => (inner) => (req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final res = await inner(req);
        return res.change(headers: _corsHeaders);
      };

  static const _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,HEAD,OPTIONS',
    'Access-Control-Allow-Headers': '*',
    'Access-Control-Expose-Headers': 'ETag,Content-Length,Content-Type',
  };

  // ── Request router ───────────────────────────────────────────────────────

  Future<Response> _handle(Request req) async {
    try {
      return await _handleInner(req);
    } catch (e) {
      return _xmlErr(500, 'InternalError', 'Internal server error: $e');
    }
  }

  Future<Response> _handleInner(Request req) async {
    final rawPath = req.requestedUri.path;
    final cleanPath =
        rawPath.startsWith('/') ? rawPath.substring(1) : rawPath;
    final method = req.method.toUpperCase();
    final qp = req.requestedUri.queryParameters;
    dev.log('[S3] $method ${req.requestedUri}', name: 'MockS3');

    // Root → ListBuckets
    if (cleanPath.isEmpty) {
      if (method == 'GET') return _listBuckets();
      return _xmlErr(405, 'MethodNotAllowed', 'Method not allowed');
    }

    final slashIdx = cleanPath.indexOf('/');
    final bucket =
        slashIdx >= 0 ? cleanPath.substring(0, slashIdx) : cleanPath;
    final key = slashIdx >= 0 ? cleanPath.substring(slashIdx + 1) : '';

    // Bucket-level operations
    if (key.isEmpty) {
      switch (method) {
        case 'GET':
          return _listObjects(bucket, qp);
        case 'PUT':
          return _createBucket(bucket);
        case 'DELETE':
          return Response(204);
        case 'HEAD':
          return getBuckets().any((b) => b.name == bucket)
              ? Response.ok('')
              : Response.notFound('');
        default:
          return _xmlErr(405, 'MethodNotAllowed', 'Method not allowed');
      }
    }

    // Object-level operations
    final token = qp['X-Amz-Signature'];
    switch (method) {
      case 'GET':
        if (token != null && !checkPresigned(token, bucket, key, 'GET')) {
          return _xmlErr(
              403, 'AccessDenied', 'Invalid or expired presigned URL');
        }
        return _getObject(bucket, key);
      case 'PUT':
        if (token != null && !checkPresigned(token, bucket, key, 'PUT')) {
          return _xmlErr(
              403, 'AccessDenied', 'Invalid or expired presigned URL');
        }
        return _putObject(req, bucket, key);
      case 'DELETE':
        await removeObject(bucket, key);
        return Response(204);
      case 'HEAD':
        return _headObject(bucket, key);
      default:
        return _xmlErr(405, 'MethodNotAllowed', 'Method not allowed');
    }
  }

  // ── Handlers ─────────────────────────────────────────────────────────────

  Response _listBuckets() {
    final items = getBuckets()
        .map((b) => '  <Bucket>\n'
            '    <Name>${_x(b.name)}</Name>\n'
            '    <CreationDate>${_iso(b.createdAt)}</CreationDate>\n'
            '  </Bucket>')
        .join('\n');
    return _xml(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">\n'
      '  <Owner><ID>mockondo</ID><DisplayName>mockondo</DisplayName></Owner>\n'
      '  <Buckets>\n$items\n  </Buckets>\n'
      '</ListAllMyBucketsResult>',
    );
  }

  Response _createBucket(String bucket) {
    if (!getBuckets().any((b) => b.name == bucket)) {
      onCreateBucket(bucket);
    }
    return Response(200, headers: {'Location': '/$bucket'});
  }

  Response _listObjects(String bucket, Map<String, String> qp) {
    if (!getBuckets().any((b) => b.name == bucket)) {
      return _xmlErr(404, 'NoSuchBucket', 'The bucket does not exist',
          bucket: bucket);
    }
    final prefix = qp['prefix'] ?? '';
    final delimiter = qp['delimiter'] ?? '';
    final maxKeys = int.tryParse(qp['max-keys'] ?? '') ?? 1000;

    final all =
        getObjects().where((o) => o.bucket == bucket).toList();
    final filtered = prefix.isEmpty
        ? all
        : all.where((o) => o.key.startsWith(prefix)).toList();

    final contents = <S3Object>[];
    final commonPrefixes = <String>{};

    for (final obj in filtered) {
      // Skip zero-byte folder placeholders from listing
      if (obj.size == 0 && obj.key.endsWith('/')) continue;
      final after = obj.key.substring(prefix.length);
      if (delimiter.isNotEmpty) {
        final idx = after.indexOf(delimiter);
        if (idx >= 0) {
          commonPrefixes.add(prefix + after.substring(0, idx + 1));
          continue;
        }
      }
      contents.add(obj);
    }

    final cxml = contents.take(maxKeys).map((o) {
      return '  <Contents>\n'
          '    <Key>${_x(o.key)}</Key>\n'
          '    <LastModified>${_iso(o.lastModified)}</LastModified>\n'
          '    <ETag>&quot;${_x(o.etag)}&quot;</ETag>\n'
          '    <Size>${o.size}</Size>\n'
          '    <StorageClass>STANDARD</StorageClass>\n'
          '  </Contents>';
    }).join('\n');

    final pxml = commonPrefixes
        .map((p) =>
            '  <CommonPrefixes><Prefix>${_x(p)}</Prefix></CommonPrefixes>')
        .join('\n');

    return _xml(
      '<?xml version="1.0" encoding="UTF-8"?>\n'
      '<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">\n'
      '  <Name>${_x(bucket)}</Name>\n'
      '  <Prefix>${_x(prefix)}</Prefix>\n'
      '  <Delimiter>${_x(delimiter)}</Delimiter>\n'
      '  <MaxKeys>$maxKeys</MaxKeys>\n'
      '  <IsTruncated>false</IsTruncated>\n'
      '$cxml\n$pxml\n'
      '</ListBucketResult>',
    );
  }

  Future<Response> _putObject(Request req, String bucket, String key) async {
    if (!getBuckets().any((b) => b.name == bucket)) {
      dev.log('[S3] PUT 404 – bucket "$bucket" not found (known: ${getBuckets().map((b) => b.name).toList()})', name: 'MockS3');
      return _xmlErr(404, 'NoSuchBucket', 'The bucket does not exist',
          bucket: bucket);
    }
    final bytes = <int>[];
    await for (final chunk in req.read()) {
      bytes.addAll(chunk);
    }
    dev.log('[S3] PUT bucket=$bucket key="$key" bytes=${bytes.length}', name: 'MockS3');
    final ct =
        req.headers['content-type'] ?? 'application/octet-stream';
    final etag = _etag(bytes);
    await addObject(
      S3Object(
        bucket: bucket,
        key: key,
        size: bytes.length,
        contentType: ct,
        lastModified: DateTime.now().toUtc(),
        etag: etag,
      ),
      bytes,
    );
    return Response.ok('', headers: {'ETag': '"$etag"'});
  }

  Future<Response> _getObject(String bucket, String key) async {
    final obj = getObjects()
        .where((o) => o.bucket == bucket && o.key == key)
        .firstOrNull;
    if (obj == null) {
      return _xmlErr(404, 'NoSuchKey', 'The key does not exist',
          bucket: bucket, key: key);
    }
    final bytes = await readContent(bucket, key);
    if (bytes == null) {
      return _xmlErr(404, 'NoSuchKey', 'Object content not found',
          bucket: bucket, key: key);
    }
    return Response.ok(
      bytes,
      headers: {
        'Content-Type': obj.contentType,
        'Content-Length': '${obj.size}',
        'ETag': '"${obj.etag}"',
        'Last-Modified': HttpDate.format(obj.lastModified),
        'Content-Disposition':
            'attachment; filename="${Uri.encodeFull(obj.fileName)}"',
      },
    );
  }

  Future<Response> _headObject(String bucket, String key) async {
    final obj = getObjects()
        .where((o) => o.bucket == bucket && o.key == key)
        .firstOrNull;
    if (obj == null) return Response.notFound('');
    return Response.ok('', headers: {
      'Content-Type': obj.contentType,
      'Content-Length': '${obj.size}',
      'ETag': '"${obj.etag}"',
      'Last-Modified': HttpDate.format(obj.lastModified),
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// FNV-1a 32-bit hash used as a simple ETag.
  String _etag(List<int> bytes) {
    int h = 0x811C9DC5;
    for (final b in bytes) {
      h ^= b;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h.toRadixString(16).padLeft(8, '0').padLeft(32, '0');
  }

  String _iso(DateTime dt) => dt
      .toUtc()
      .toIso8601String()
      .replaceFirst(RegExp(r'\.\d+Z$'), 'Z');

  String _x(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  Response _xml(String body) =>
      Response.ok(body, headers: {'Content-Type': 'application/xml'});

  Response _xmlErr(int code, String errCode, String msg,
      {String? bucket, String? key}) {
    final bk =
        bucket != null ? '<BucketName>${_x(bucket)}</BucketName>' : '';
    final kk = key != null ? '<Key>${_x(key)}</Key>' : '';
    return Response(
      code,
      body:
          '<?xml version="1.0" encoding="UTF-8"?>\n<Error>'
          '<Code>$errCode</Code><Message>${_x(msg)}</Message>'
          '$bk$kk</Error>',
      headers: {'Content-Type': 'application/xml'},
    );
  }
}
