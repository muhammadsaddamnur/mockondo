import 'package:flutter_test/flutter_test.dart';
import 'package:mockondo/core/curl_utils.dart';
import 'package:mockondo/features/http_client/data/models/http_client_model.dart';

void main() {
  // ── CurlUtils.generate ─────────────────────────────────────────────────────

  group('CurlUtils.generate', () {
    test('produces minimal GET command', () {
      final result = CurlUtils.generate(
        method: 'GET',
        url: 'https://example.com/api',
      );
      expect(result, contains('curl -X GET'));
      expect(result, contains("'https://example.com/api'"));
    });

    test('includes headers with -H flag', () {
      final result = CurlUtils.generate(
        method: 'POST',
        url: 'https://example.com',
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer token'},
      );
      expect(result, contains("-H 'Content-Type: application/json'"));
      expect(result, contains("-H 'Authorization: Bearer token'"));
    });

    test('includes body with --data-raw flag', () {
      final result = CurlUtils.generate(
        method: 'POST',
        url: 'https://example.com',
        body: '{"key":"value"}',
      );
      expect(result, contains('--data-raw'));
      expect(result, contains('{"key":"value"}'));
    });

    test('escapes single quotes in body', () {
      final result = CurlUtils.generate(
        method: 'POST',
        url: 'https://example.com',
        body: "it's a test",
      );
      // Single quote inside body gets escaped as '\''
      expect(result, contains(r"'\''"));
    });

    test('omits --data-raw when body is empty', () {
      final result = CurlUtils.generate(method: 'GET', url: 'https://example.com');
      expect(result, isNot(contains('--data-raw')));
    });

    test('uses newline continuation for multi-part commands', () {
      final result = CurlUtils.generate(
        method: 'POST',
        url: 'https://example.com',
        headers: {'Accept': 'application/json'},
        body: '{}',
      );
      expect(result, contains('\\\n'));
    });
  });

  // ── CurlUtils.parse ────────────────────────────────────────────────────────

  group('CurlUtils.parse', () {
    test('returns null for non-curl input', () {
      expect(CurlUtils.parse('wget https://example.com'), isNull);
      expect(CurlUtils.parse(''), isNull);
      expect(CurlUtils.parse('GET /api'), isNull);
    });

    test('parses minimal curl GET', () {
      final item = CurlUtils.parse("curl 'https://example.com/api'");
      expect(item, isNotNull);
      expect(item!.method, equals('GET'));
      expect(item.url, equals('https://example.com/api'));
    });

    test('parses method from -X flag', () {
      final item = CurlUtils.parse("curl -X DELETE 'https://example.com/item/1'");
      expect(item, isNotNull);
      expect(item!.method, equals('DELETE'));
    });

    test('parses method from --request flag', () {
      final item = CurlUtils.parse("curl --request PUT 'https://example.com'");
      expect(item, isNotNull);
      expect(item!.method, equals('PUT'));
    });

    test('parses single header', () {
      final item = CurlUtils.parse("curl -H 'Content-Type: application/json' 'https://example.com'");
      expect(item, isNotNull);
      expect(item!.headers.any((h) => h.key == 'Content-Type' && h.value == 'application/json'), isTrue);
    });

    test('parses multiple headers', () {
      final item = CurlUtils.parse(
        "curl -H 'Content-Type: application/json' -H 'Authorization: Bearer token' 'https://example.com'",
      );
      expect(item, isNotNull);
      expect(item!.headers.length, equals(2));
    });

    test('parses JSON body from --data-raw flag', () {
      final item = CurlUtils.parse(
        "curl -X POST --data-raw '{\"name\":\"Alice\"}' 'https://example.com/users'",
      );
      expect(item, isNotNull);
      expect(item!.body, equals('{"name":"Alice"}'));
      expect(item.bodyType, equals(RequestBodyType.json));
    });

    test('parses plain text body from -d flag', () {
      final item = CurlUtils.parse("curl -X POST -d 'hello world' 'https://example.com'");
      expect(item, isNotNull);
      expect(item!.body, equals('hello world'));
      expect(item.bodyType, equals(RequestBodyType.text));
    });

    test('infers POST when body is present but no -X flag', () {
      final item = CurlUtils.parse("curl -d '{\"x\":1}' 'https://example.com'");
      expect(item, isNotNull);
      expect(item!.method, equals('POST'));
    });

    test('extracts query params from URL', () {
      final item = CurlUtils.parse("curl 'https://example.com/api?page=1&limit=20'");
      expect(item, isNotNull);
      expect(item!.params.any((p) => p.key == 'page' && p.value == '1'), isTrue);
      expect(item.params.any((p) => p.key == 'limit' && p.value == '20'), isTrue);
      // URL itself should not contain the query string
      expect(item.url, isNot(contains('?')));
    });

    test('parses multiline curl (backslash continuations)', () {
      final item = CurlUtils.parse(
        "curl -X POST \\\n  -H 'Content-Type: application/json' \\\n  'https://example.com'",
      );
      expect(item, isNotNull);
      expect(item!.method, equals('POST'));
    });

    test('parses form fields from -F flag', () {
      final item = CurlUtils.parse(
        "curl -X POST -F 'name=Alice' -F 'role=admin' 'https://example.com/upload'",
      );
      expect(item, isNotNull);
      expect(item!.bodyType, equals(RequestBodyType.formData));
      expect(item.formData.any((f) => f.key == 'name' && f.value == 'Alice'), isTrue);
    });

    test('derives a readable name from URL path', () {
      final item = CurlUtils.parse("curl 'https://example.com/api/users'");
      expect(item, isNotNull);
      expect(item!.name, contains('api'));
    });

    test('generates a unique id for each parsed item', () {
      final a = CurlUtils.parse("curl 'https://example.com'");
      final b = CurlUtils.parse("curl 'https://example.com'");
      expect(a!.id, isNot(equals(b!.id)));
    });
  });
}
