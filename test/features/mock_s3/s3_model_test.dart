import 'package:flutter_test/flutter_test.dart';
import 'package:mockondo/features/mock_s3/data/models/s3_model.dart';

void main() {
  // ── S3Config ───────────────────────────────────────────────────────────────

  group('S3Config', () {
    test('has sensible defaults', () {
      const config = S3Config();
      expect(config.host, equals('127.0.0.1'));
      expect(config.port, equals(9000));
      expect(config.accessKey, equals('mockondo'));
      expect(config.secretKey, equals('mockondo123'));
      expect(config.region, equals('us-east-1'));
    });

    test('toJson → fromJson round-trip is lossless', () {
      const original = S3Config(
        host: '192.168.1.100',
        port: 9001,
        accessKey: 'mykey',
        secretKey: 'mysecret',
        region: 'ap-southeast-1',
      );
      final restored = S3Config.fromJson(original.toJson());
      expect(restored.host, equals(original.host));
      expect(restored.port, equals(original.port));
      expect(restored.accessKey, equals(original.accessKey));
      expect(restored.secretKey, equals(original.secretKey));
      expect(restored.region, equals(original.region));
    });

    test('fromJson uses defaults for missing fields', () {
      final config = S3Config.fromJson({});
      expect(config.host, equals('127.0.0.1'));
      expect(config.port, equals(9000));
      expect(config.accessKey, equals('mockondo'));
      expect(config.secretKey, equals('mockondo123'));
      expect(config.region, equals('us-east-1'));
    });

    test('copyWith changes only specified fields', () {
      const original = S3Config();
      final copy = original.copyWith(port: 9999, region: 'eu-west-1');
      expect(copy.port, equals(9999));
      expect(copy.region, equals('eu-west-1'));
      expect(copy.host, equals(original.host));
      expect(copy.accessKey, equals(original.accessKey));
    });
  });

  // ── S3Bucket ───────────────────────────────────────────────────────────────

  group('S3Bucket', () {
    test('toJson → fromJson round-trip is lossless', () {
      final now = DateTime.utc(2024, 6, 15, 10, 30, 0);
      final original = S3Bucket(name: 'my-bucket', createdAt: now);
      final restored = S3Bucket.fromJson(original.toJson());
      expect(restored.name, equals('my-bucket'));
      expect(restored.createdAt, equals(now));
    });

    test('toJson serialises createdAt as ISO 8601 string', () {
      final now = DateTime.utc(2024, 1, 1);
      final bucket = S3Bucket(name: 'b', createdAt: now);
      final json = bucket.toJson();
      expect(json['createdAt'], isA<String>());
      expect(DateTime.parse(json['createdAt'] as String), equals(now));
    });
  });

  // ── S3Object ───────────────────────────────────────────────────────────────

  group('S3Object', () {
    S3Object sample() => S3Object(
          bucket: 'my-bucket',
          key: 'images/photo.jpg',
          size: 102400,
          contentType: 'image/jpeg',
          lastModified: DateTime.utc(2024, 3, 20),
          etag: 'abc123def456',
        );

    test('toJson → fromJson round-trip is lossless', () {
      final original = sample();
      final restored = S3Object.fromJson(original.toJson());
      expect(restored.bucket, equals(original.bucket));
      expect(restored.key, equals(original.key));
      expect(restored.size, equals(original.size));
      expect(restored.contentType, equals(original.contentType));
      expect(restored.lastModified, equals(original.lastModified));
      expect(restored.etag, equals(original.etag));
    });

    test('fileName returns the last path segment', () {
      expect(sample().fileName, equals('photo.jpg'));
    });

    test('fileName for root-level key returns the key itself', () {
      final obj = S3Object(
        bucket: 'b',
        key: 'readme.md',
        size: 0,
        contentType: 'text/markdown',
        lastModified: DateTime.now(),
        etag: '',
      );
      expect(obj.fileName, equals('readme.md'));
    });

    test('fileName strips trailing slash for directory-like keys', () {
      final obj = S3Object(
        bucket: 'b',
        key: 'folder/subdir/',
        size: 0,
        contentType: 'application/x-directory',
        lastModified: DateTime.now(),
        etag: '',
      );
      expect(obj.fileName, equals('subdir'));
    });

    test('fromJson uses defaults for missing optional fields', () {
      final obj = S3Object.fromJson({
        'bucket': 'b',
        'key': 'file.txt',
        'lastModified': DateTime.now().toIso8601String(),
      });
      expect(obj.size, equals(0));
      expect(obj.contentType, equals('application/octet-stream'));
      expect(obj.etag, equals(''));
    });
  });

  // ── PresignedUrl ───────────────────────────────────────────────────────────

  group('PresignedUrl', () {
    test('isExpired returns false when expiry is in the future', () {
      final url = PresignedUrl(
        url: 'https://example.com?token=abc',
        operation: 'GET',
        bucket: 'b',
        key: 'k',
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        token: 'abc',
      );
      expect(url.isExpired, isFalse);
    });

    test('isExpired returns true when expiry is in the past', () {
      final url = PresignedUrl(
        url: 'https://example.com?token=xyz',
        operation: 'PUT',
        bucket: 'b',
        key: 'k',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
        token: 'xyz',
      );
      expect(url.isExpired, isTrue);
    });
  });

  // ── S3Item ─────────────────────────────────────────────────────────────────

  group('S3Item', () {
    test('folder item has isFolder=true and correct displayName', () {
      const item = S3Item.folder('images/thumbnails/');
      expect(item.isFolder, isTrue);
      expect(item.object, isNull);
      expect(item.displayName, equals('thumbnails/'));
    });

    test('object item has isFolder=false and correct displayName', () {
      final obj = S3Object(
        bucket: 'b',
        key: 'docs/report.pdf',
        size: 5000,
        contentType: 'application/pdf',
        lastModified: DateTime.now(),
        etag: '',
      );
      final item = S3Item.object(obj);
      expect(item.isFolder, isFalse);
      expect(item.displayName, equals('report.pdf'));
    });

    test('folder displayName handles path without trailing slash', () {
      const item = S3Item.folder('images/archive');
      expect(item.displayName, equals('archive/'));
    });

    test('folder displayName for root-level prefix', () {
      const item = S3Item.folder('photos/');
      expect(item.displayName, equals('photos/'));
    });
  });
}
