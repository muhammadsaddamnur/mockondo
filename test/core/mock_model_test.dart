import 'package:flutter_test/flutter_test.dart';
import 'package:mockondo/core/mock_model.dart';

void main() {
  // ── MockModel ──────────────────────────────────────────────────────────────

  group('MockModel serialisation', () {
    MockModel sample() => MockModel(
          enable: true,
          endpoint: '/api/users',
          statusCode: 200,
          delay: 100,
          responseHeader: {'Content-Type': 'application/json'},
          responseBody: '{"data": []}',
          method: 'GET',
        );

    test('toJson includes all fields', () {
      final json = sample().toJson();
      expect(json['enable'], isTrue);
      expect(json['endpoint'], equals('/api/users'));
      expect(json['status_code'], equals(200));
      expect(json['delay'], equals(100));
      expect((json['response_header'] as Map)['Content-Type'], equals('application/json'));
      expect(json['response_body'], equals('{"data": []}'));
      expect(json['method'], equals('GET'));
    });

    test('fromJson → toJson round-trip is lossless', () {
      final original = sample();
      final restored = MockModel.fromJson(original.toJson());

      expect(restored.enable, equals(original.enable));
      expect(restored.endpoint, equals(original.endpoint));
      expect(restored.statusCode, equals(original.statusCode));
      expect(restored.delay, equals(original.delay));
      expect(restored.responseBody, equals(original.responseBody));
      expect(restored.method, equals(original.method));
    });

    test('fromJson uses defaults for missing optional fields', () {
      final json = {
        'enable': false,
        'endpoint': '/test',
        'status_code': 404,
        'response_body': '{}',
        'method': 'POST',
      };
      final model = MockModel.fromJson(json);
      expect(model.delay, isNull);
      expect(model.responseHeader, isNull);
      expect(model.rules, isNull);
    });

    test('copyWith only changes specified fields', () {
      final original = sample();
      final copy = original.copyWith(statusCode: 201, method: 'POST');
      expect(copy.statusCode, equals(201));
      expect(copy.method, equals('POST'));
      expect(copy.endpoint, equals(original.endpoint)); // unchanged
    });
  });

  // ── Rules ──────────────────────────────────────────────────────────────────

  group('Rules serialisation', () {
    Rules sample() => Rules(
          type: RulesType.response,
          rules: {
            'label': 'Admin only',
            'status_code': 403,
            'logic': 'and',
            'conditions': [],
          },
          response: '{"error": "forbidden"}',
        );

    test('toJson → fromJson round-trip preserves type and response', () {
      final original = sample();
      final restored = Rules.fromJson(original.toJson());
      expect(restored.type, equals(RulesType.response));
      expect(restored.response, equals(original.response));
      expect(restored.rules['label'], equals('Admin only'));
    });

    test('fromJson defaults to RulesType.response for unknown type', () {
      final json = {
        'type': 'nonexistent_type',
        'rules': <String, dynamic>{},
        'response': '',
      };
      final rule = Rules.fromJson(json);
      expect(rule.type, equals(RulesType.response));
    });
  });

  // ── ResponseRulesExt ───────────────────────────────────────────────────────

  group('ResponseRulesExt', () {
    test('label returns the label string from the rules map', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {'label': 'My Rule'},
        response: '',
      );
      expect(rule.label, equals('My Rule'));
    });

    test('label defaults to empty string when absent', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {},
        response: '',
      );
      expect(rule.label, equals(''));
    });

    test('ruleStatusCode parses int value', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {'status_code': 422},
        response: '',
      );
      expect(rule.ruleStatusCode, equals(422));
    });

    test('ruleStatusCode parses string value', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {'status_code': '404'},
        response: '',
      );
      expect(rule.ruleStatusCode, equals(404));
    });

    test('ruleStatusCode defaults to 200 when absent', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {},
        response: '',
      );
      expect(rule.ruleStatusCode, equals(200));
    });

    test('logic returns AND by default', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {},
        response: '',
      );
      expect(rule.logic, equals(RulesLogic.and));
    });

    test('logic returns OR when set to "or"', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {'logic': 'or'},
        response: '',
      );
      expect(rule.logic, equals(RulesLogic.or));
    });

    test('conditions deserialises the list correctly', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {
          'conditions': [
            {
              'id': 'c1',
              'target': 'queryParam',
              'key': 'status',
              'operator': 'equals',
              'value': 'active',
            },
          ],
        },
        response: '',
      );
      final conds = rule.conditions;
      expect(conds.length, equals(1));
      expect(conds.first.key, equals('status'));
      expect(conds.first.target, equals(ResponseRuleTarget.queryParam));
      expect(conds.first.operator, equals(ResponseRuleOperator.equals));
      expect(conds.first.value, equals('active'));
    });
  });

  // ── ResponseCondition ──────────────────────────────────────────────────────

  group('ResponseCondition serialisation', () {
    ResponseCondition sample() => ResponseCondition(
          id: 'cond-1',
          target: ResponseRuleTarget.requestHeader,
          key: 'authorization',
          operator: ResponseRuleOperator.contains,
          value: 'Bearer',
        );

    test('toJson → fromJson round-trip is lossless', () {
      final original = sample();
      final restored = ResponseCondition.fromJson(original.toJson());
      expect(restored.id, equals(original.id));
      expect(restored.target, equals(original.target));
      expect(restored.key, equals(original.key));
      expect(restored.operator, equals(original.operator));
      expect(restored.value, equals(original.value));
    });

    test('fromJson uses queryParam as default target for unknown values', () {
      final json = {
        'id': 'x',
        'target': 'unknownTarget',
        'key': 'k',
        'operator': 'equals',
        'value': 'v',
      };
      final cond = ResponseCondition.fromJson(json);
      expect(cond.target, equals(ResponseRuleTarget.queryParam));
    });

    test('fromJson uses equals as default operator for unknown values', () {
      final json = {
        'id': 'x',
        'target': 'queryParam',
        'key': 'k',
        'operator': 'unknownOp',
        'value': 'v',
      };
      final cond = ResponseCondition.fromJson(json);
      expect(cond.operator, equals(ResponseRuleOperator.equals));
    });
  });

  // ── MockData serialisation ─────────────────────────────────────────────────

  group('MockData.toJson', () {
    test('serialises all public fields excluding server', () {
      final data = MockData(
        id: 1,
        name: 'My Project',
        host: '0.0.0.0',
        port: 3000,
        mockModels: [],
      );
      final json = data.toJson();
      expect(json['id'], equals(1));
      expect(json['name'], equals('My Project'));
      expect(json['host'], equals('0.0.0.0'));
      expect(json['port'], equals(3000));
      expect(json['mock_models'], isEmpty);
      expect(json.containsKey('server'), isFalse);
    });
  });
}
