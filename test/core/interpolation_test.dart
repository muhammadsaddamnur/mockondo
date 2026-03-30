import 'package:flutter_test/flutter_test.dart';
import 'package:mockondo/core/interpolation.dart';
import 'package:shelf/shelf.dart' as shelf;

void main() {
  final interp = Interpolation();

  // ── random.* ────────────────────────────────────────────────────────────────

  group('random interpolations', () {
    test('random.uuid produces a non-empty quoted string', () {
      final result = interp.excute(before: r'${random.uuid}', data: '');
      // jsonEncode wraps the UUID in double quotes
      expect(result, matches(RegExp(r'^"[0-9a-f\-]{36}"$')));
    });

    test('random.integer.50 returns a number in [0, 50)', () {
      for (var i = 0; i < 20; i++) {
        final raw = interp.excute(before: r'${random.integer.50}', data: '');
        final value = int.parse(raw);
        expect(value, greaterThanOrEqualTo(0));
        expect(value, lessThan(50));
      }
    });

    test('random.double.5 returns a number in [0.0, 5.0)', () {
      for (var i = 0; i < 10; i++) {
        final raw = interp.excute(before: r'${random.double.5}', data: '');
        final value = double.parse(raw);
        expect(value, greaterThanOrEqualTo(0.0));
        expect(value, lessThan(5.0));
      }
    });

    test('random.string.10 produces a quoted 10-character string', () {
      final result = interp.excute(before: r'${random.string.10}', data: '');
      // Strip JSON quotes, then check length
      final unquoted = result.replaceAll('"', '');
      expect(unquoted.length, equals(10));
    });

    test('random.name returns a non-empty quoted string', () {
      final result = interp.excute(before: r'${random.name}', data: '');
      expect(result.startsWith('"'), isTrue);
      expect(result.length, greaterThan(2));
    });

    test('random.email contains an @ sign', () {
      final result = interp.excute(before: r'${random.email}', data: '');
      expect(result, contains('@'));
    });

    test('random.image.400x400 returns the placehold.co URL', () {
      final result = interp.excute(before: r'${random.image.400x400}', data: '');
      expect(result, equals('"https://placehold.co/400x400"'));
    });

    test('random.image.200x200.index appends ?text=<data>', () {
      final result = interp.excute(
        before: r'${random.image.200x200.index}',
        data: '5',
      );
      expect(result, equals('"https://placehold.co/200x200?text=5"'));
    });

    test('random.image.300x300.hello appends ?text=hello', () {
      final result = interp.excute(
        before: r'${random.image.300x300.hello}',
        data: '',
      );
      expect(result, equals('"https://placehold.co/300x300?text=hello"'));
    });

    test('random.index returns the current data value unchanged', () {
      final result = interp.excute(before: r'${random.index}', data: '42');
      expect(result, equals('42'));
    });

    test('unknown random.* placeholder is left as-is', () {
      final result = interp.excute(
        before: r'${random.doesnotexist}',
        data: '',
      );
      expect(result, equals(r'${random.doesnotexist}'));
    });
  });

  // ── request.* ───────────────────────────────────────────────────────────────

  group('request interpolations', () {
    shelf.Request makeRequest({
      String method = 'GET',
      String path = '/api/items',
      Map<String, String> query = const {},
      Map<String, String> headers = const {},
    }) {
      final uri = Uri.parse(
        'http://localhost:8080$path${query.isNotEmpty ? '?${Uri(queryParameters: query).query}' : ''}',
      );
      return shelf.Request(method, uri, headers: headers);
    }

    test('request.url.query reads a numeric query param without quotes', () {
      final req = makeRequest(query: {'page': '3'});
      final result = interp.excute(
        before: r'${request.url.query.page}',
        data: '',
        request: req,
      );
      expect(result, equals('3')); // numeric — no quotes
    });

    test('request.url.query reads a string query param with quotes', () {
      final req = makeRequest(query: {'name': 'alice'});
      final result = interp.excute(
        before: r'${request.url.query.name}',
        data: '',
        request: req,
      );
      expect(result, equals('"alice"'));
    });

    test('request.url.query returns empty string for missing param', () {
      final req = makeRequest();
      final result = interp.excute(
        before: r'${request.url.query.missing}',
        data: '',
        request: req,
      );
      expect(result, equals('""'));
    });

    test('request.header reads a header value case-insensitively', () {
      final req = makeRequest(headers: {'Authorization': 'Bearer abc'});
      final result = interp.excute(
        before: r'${request.header.authorization}',
        data: '',
        request: req,
      );
      expect(result, equals('"Bearer abc"'));
    });

    test('request.body reads a top-level JSON field', () {
      final req = makeRequest(method: 'POST');
      final result = interp.excute(
        before: r'${request.body.username}',
        data: '',
        request: req,
        requestBody: '{"username": "bob"}',
      );
      expect(result, equals('"bob"'));
    });

    test('request.body supports dot-notation for nested fields', () {
      final req = makeRequest(method: 'POST');
      final result = interp.excute(
        before: r'${request.body.user.email}',
        data: '',
        request: req,
        requestBody: '{"user": {"email": "bob@example.com"}}',
      );
      expect(result, equals('"bob@example.com"'));
    });

    test('request.body returns empty string when requestBody is not provided', () {
      // When requestBody is null the handler falls through to return `data`,
      // which defaults to an empty string here.
      final req = makeRequest(method: 'POST');
      final result = interp.excute(
        before: r'${request.body.field}',
        data: '',
        request: req,
      );
      expect(result, equals(''));
    });
  });

  // ── pagination.* ────────────────────────────────────────────────────────────

  group('pagination interpolations', () {
    test('pagination.data returns the pre-generated data string', () {
      final result = interp.excute(
        before: r'${pagination.data}',
        data: '[1,2,3]',
      );
      expect(result, equals('[1,2,3]'));
    });

    test('pagination.request.url.query reads query param', () {
      final req = shelf.Request(
        'GET',
        Uri.parse('http://localhost:8080/api?page=2'),
      );
      final result = interp.excute(
        before: r'${pagination.request.url.query.page}',
        data: '',
        request: req,
      );
      expect(result, equals('"2"'));
    });
  });

  // ── Unknown / passthrough ──────────────────────────────────────────────────

  group('unknown placeholders', () {
    test('unrecognised namespace is left unchanged', () {
      final result = interp.excute(
        before: r'hello ${unknown.placeholder} world',
        data: '',
      );
      expect(result, equals(r'hello ${unknown.placeholder} world'));
    });

    test('plain text with no placeholders passes through unchanged', () {
      const input = '{"key": "value", "count": 5}';
      final result = interp.excute(before: input, data: '');
      expect(result, equals(input));
    });

    test('multiple placeholders in one string are all resolved', () {
      final result = interp.excute(
        before: r'{"id": ${random.index}, "email": ${random.email}}',
        data: '7',
      );
      expect(result, contains('"id": 7'));
      expect(result, contains('@')); // email contains @
    });
  });

  // ── evaluateMathExpression ─────────────────────────────────────────────────

  group('evaluateMathExpression', () {
    test('evaluates simple addition', () {
      expect(interp.evaluateMathExpression('2+3'), equals(5));
    });

    test('evaluates multiplication', () {
      expect(interp.evaluateMathExpression('4*5'), equals(20));
    });

    test('evaluates floating point division', () {
      expect(interp.evaluateMathExpression('7/2'), closeTo(3.5, 0.001));
    });

    test('evaluates compound expression', () {
      expect(interp.evaluateMathExpression('(10+2)*3'), equals(36));
    });
  });

  // ── header() ──────────────────────────────────────────────────────────────

  group('header()', () {
    test('wraps placeholders in JSON quotes so they survive encode/decode', () {
      const input = '{"X-Token": "\${random.uuid}"}';
      final result = interp.header(header: input);
      // The placeholder should be quoted as a JSON string value
      expect(result, contains(r'${random.uuid}'));
    });

    test('reverse mode restores the raw placeholder syntax', () {
      const stored = r'{"X-Token": "${random.uuid}"}';
      final result = interp.header(header: stored, reverse: true);
      expect(result, contains(r'${random.uuid}'));
    });
  });
}
