import 'package:flutter_test/flutter_test.dart';
import 'package:mockondo/core/utils.dart';

void main() {
  group('Utils.randomString', () {
    test('returns a string of the requested length', () {
      for (final len in [0, 1, 10, 50, 100]) {
        expect(Utils.randomString(len).length, len);
      }
    });

    test('only contains alphanumeric characters', () {
      final result = Utils.randomString(200);
      final alphanumeric = RegExp(r'^[a-zA-Z0-9]+$');
      expect(alphanumeric.hasMatch(result), isTrue);
    });

    test('produces different values on successive calls', () {
      // Extremely unlikely to collide for length >= 8
      final a = Utils.randomString(16);
      final b = Utils.randomString(16);
      expect(a, isNot(equals(b)));
    });
  });

  group('Utils.parseHeader', () {
    test('returns null for an empty string', () {
      expect(Utils.parseHeader('', interpolation: false), isNull);
    });

    test('parses a flat JSON object into a String→Object map', () {
      const json = '{"Content-Type": "application/json", "X-Version": "1"}';
      final result = Utils.parseHeader(json, interpolation: false);
      expect(result, isNotNull);
      expect(result!['Content-Type'], equals('application/json'));
      expect(result['X-Version'], equals('1'));
    });

    test('handles double-quote artefacts produced by the interpolation engine', () {
      // The interpolation engine wraps placeholder values in extra quotes;
      // parseHeader strips the resulting "" sequences before decoding.
      const json = '{"Authorization": "Bearer token123"}';
      final result = Utils.parseHeader(json, interpolation: false);
      expect(result!['Authorization'], equals('Bearer token123'));
    });

    test('throws FormatException for a non-object JSON value', () {
      expect(
        () => Utils.parseHeader('["array"]', interpolation: false),
        throwsFormatException,
      );
    });

    test('throws FormatException for invalid JSON', () {
      expect(
        () => Utils.parseHeader('{bad json}', interpolation: false),
        throwsA(anything),
      );
    });
  });
}
