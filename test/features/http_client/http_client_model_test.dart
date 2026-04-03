import 'package:flutter_test/flutter_test.dart';
import 'package:mockondo/features/http_client/data/models/http_client_model.dart';

void main() {
  // ── KeyValuePair ───────────────────────────────────────────────────────────

  group('KeyValuePair', () {
    test('defaults to enabled=true and empty strings', () {
      final kv = KeyValuePair();
      expect(kv.key, equals(''));
      expect(kv.value, equals(''));
      expect(kv.enabled, isTrue);
    });

    test('toJson → fromJson round-trip is lossless', () {
      final original = KeyValuePair(key: 'Authorization', value: 'Bearer xyz', enabled: false);
      final restored = KeyValuePair.fromJson(original.toJson());
      expect(restored.key, equals(original.key));
      expect(restored.value, equals(original.value));
      expect(restored.enabled, equals(original.enabled));
    });

    test('fromJson uses defaults for missing keys', () {
      final kv = KeyValuePair.fromJson({});
      expect(kv.key, equals(''));
      expect(kv.value, equals(''));
      expect(kv.enabled, isTrue);
    });

    test('copyWith changes only specified fields', () {
      final original = KeyValuePair(key: 'X-Token', value: 'abc', enabled: true);
      final copy = original.copyWith(enabled: false);
      expect(copy.enabled, isFalse);
      expect(copy.key, equals('X-Token'));
      expect(copy.value, equals('abc'));
    });
  });

  // ── RequestFormField ───────────────────────────────────────────────────────

  group('RequestFormField', () {
    test('defaults to text type, enabled, empty fields', () {
      final field = RequestFormField();
      expect(field.type, equals(RequestFormFieldType.text));
      expect(field.enabled, isTrue);
      expect(field.key, equals(''));
      expect(field.value, equals(''));
      expect(field.filePath, isNull);
    });

    test('toJson → fromJson round-trip for text field', () {
      final original = RequestFormField(key: 'name', value: 'Alice', enabled: true);
      final restored = RequestFormField.fromJson(original.toJson());
      expect(restored.key, equals('name'));
      expect(restored.value, equals('Alice'));
      expect(restored.type, equals(RequestFormFieldType.text));
    });

    test('toJson → fromJson round-trip for file field', () {
      final original = RequestFormField(
        key: 'file',
        value: 'report.pdf',
        type: RequestFormFieldType.file,
        filePath: '/tmp/report.pdf',
      );
      final restored = RequestFormField.fromJson(original.toJson());
      expect(restored.type, equals(RequestFormFieldType.file));
      expect(restored.filePath, equals('/tmp/report.pdf'));
    });

    test('displayFileName uses filePath when set', () {
      final field = RequestFormField(
        key: 'doc',
        value: 'fallback.txt',
        type: RequestFormFieldType.file,
        filePath: '/home/user/documents/report.pdf',
      );
      expect(field.displayFileName, equals('report.pdf'));
    });

    test('displayFileName falls back to value when filePath is null', () {
      final field = RequestFormField(key: 'doc', value: 'fallback.txt');
      expect(field.displayFileName, equals('fallback.txt'));
    });

    test('fromJson defaults to text type for unknown type string', () {
      final field = RequestFormField.fromJson({'key': 'x', 'value': 'y', 'type': 'unknown'});
      expect(field.type, equals(RequestFormFieldType.text));
    });

    test('copyWith changes only specified fields', () {
      final original = RequestFormField(key: 'a', value: 'b', type: RequestFormFieldType.file);
      final copy = original.copyWith(value: 'c');
      expect(copy.value, equals('c'));
      expect(copy.key, equals('a'));
      expect(copy.type, equals(RequestFormFieldType.file));
    });
  });

  // ── HttpRequestItem ────────────────────────────────────────────────────────

  group('HttpRequestItem', () {
    HttpRequestItem sample() => HttpRequestItem(
          id: 'req-1',
          name: 'Get Users',
          method: 'GET',
          url: 'https://api.example.com/users',
          headers: [KeyValuePair(key: 'Accept', value: 'application/json')],
          params: [KeyValuePair(key: 'page', value: '1')],
          body: '',
          bodyType: RequestBodyType.none,
          groupId: 'grp-1',
        );

    test('toJson includes all fields', () {
      final json = sample().toJson();
      expect(json['id'], equals('req-1'));
      expect(json['name'], equals('Get Users'));
      expect(json['method'], equals('GET'));
      expect(json['url'], equals('https://api.example.com/users'));
      expect(json['group_id'], equals('grp-1'));
      expect((json['headers'] as List).length, equals(1));
      expect((json['params'] as List).length, equals(1));
    });

    test('fromJson → toJson round-trip is lossless', () {
      final original = sample();
      final restored = HttpRequestItem.fromJson(original.toJson());
      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.method, equals(original.method));
      expect(restored.url, equals(original.url));
      expect(restored.groupId, equals(original.groupId));
      expect(restored.headers.first.key, equals('Accept'));
      expect(restored.params.first.key, equals('page'));
    });

    test('fromJson uses defaults for missing fields', () {
      final item = HttpRequestItem.fromJson({'id': 'x'});
      expect(item.name, equals('New Request'));
      expect(item.method, equals('GET'));
      expect(item.url, equals(''));
      expect(item.headers, isEmpty);
      expect(item.params, isEmpty);
      expect(item.formData, isEmpty);
      expect(item.bodyType, equals(RequestBodyType.json));
      expect(item.groupId, isNull);
    });

    test('copyWith preserves id and groupId', () {
      final original = sample();
      final copy = original.copyWith(name: 'Updated', method: 'POST');
      expect(copy.id, equals(original.id));
      expect(copy.groupId, equals(original.groupId));
      expect(copy.name, equals('Updated'));
      expect(copy.method, equals('POST'));
    });

    test('bodyType round-trips all enum values', () {
      for (final type in RequestBodyType.values) {
        final item = HttpRequestItem(id: 'x', bodyType: type);
        final restored = HttpRequestItem.fromJson(item.toJson());
        expect(restored.bodyType, equals(type));
      }
    });

    test('formData is serialised and deserialised correctly', () {
      final item = HttpRequestItem(
        id: 'req-2',
        formData: [
          RequestFormField(key: 'username', value: 'bob'),
          RequestFormField(
            key: 'avatar',
            type: RequestFormFieldType.file,
            filePath: '/tmp/avatar.png',
          ),
        ],
      );
      final restored = HttpRequestItem.fromJson(item.toJson());
      expect(restored.formData.length, equals(2));
      expect(restored.formData[1].type, equals(RequestFormFieldType.file));
    });
  });

  // ── HttpRequestGroup ───────────────────────────────────────────────────────

  group('HttpRequestGroup', () {
    test('defaults to isExpanded=true', () {
      final group = HttpRequestGroup(id: 'g1', name: 'Auth');
      expect(group.isExpanded, isTrue);
    });

    test('toJson → fromJson round-trip is lossless', () {
      final original = HttpRequestGroup(id: 'g2', name: 'Public APIs', isExpanded: false);
      final restored = HttpRequestGroup.fromJson(original.toJson());
      expect(restored.id, equals('g2'));
      expect(restored.name, equals('Public APIs'));
      expect(restored.isExpanded, isFalse);
    });

    test('fromJson uses defaults for missing fields', () {
      final group = HttpRequestGroup.fromJson({'id': 'g3', 'name': 'X'});
      expect(group.isExpanded, isTrue);
    });

    test('copyWith changes only specified fields', () {
      final original = HttpRequestGroup(id: 'g4', name: 'Old', isExpanded: false);
      final copy = original.copyWith(name: 'New', isExpanded: true);
      expect(copy.id, equals('g4'));
      expect(copy.name, equals('New'));
      expect(copy.isExpanded, isTrue);
    });
  });

  // ── HttpResponseResult ─────────────────────────────────────────────────────

  group('HttpResponseResult', () {
    test('isSuccess is true for 2xx status codes', () {
      for (final code in [200, 201, 204, 299]) {
        final result = HttpResponseResult(
          statusCode: code,
          body: '',
          headers: {},
          durationMs: 0,
        );
        expect(result.isSuccess, isTrue, reason: 'expected $code to be success');
      }
    });

    test('isSuccess is false for non-2xx status codes', () {
      for (final code in [199, 300, 400, 404, 500]) {
        final result = HttpResponseResult(
          statusCode: code,
          body: '',
          headers: {},
          durationMs: 0,
        );
        expect(result.isSuccess, isFalse, reason: 'expected $code to be failure');
      }
    });

    test('prettyBody formats valid JSON', () {
      final result = HttpResponseResult(
        statusCode: 200,
        body: '{"name":"Alice","age":30}',
        headers: {},
        durationMs: 10,
      );
      final pretty = result.prettyBody;
      expect(pretty, contains('\n'));
      expect(pretty, contains('"name"'));
    });

    test('prettyBody returns raw string for non-JSON body', () {
      const raw = 'plain text response';
      final result = HttpResponseResult(
        statusCode: 200,
        body: raw,
        headers: {},
        durationMs: 5,
      );
      expect(result.prettyBody, equals(raw));
    });
  });
}
