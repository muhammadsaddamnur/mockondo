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

    test('responseHeader is included in toJson when set', () {
      final rule = Rules(
        type: RulesType.response,
        rules: {},
        response: '{}',
        responseHeader: {'X-Custom': 'value'},
      );
      final json = rule.toJson();
      expect(json['response_header'], isNotNull);
      expect((json['response_header'] as Map)['X-Custom'], equals('value'));
    });

    test('responseHeader is absent from toJson when null', () {
      final rule = Rules(type: RulesType.response, rules: {}, response: '');
      expect(rule.toJson().containsKey('response_header'), isFalse);
    });

    test('copyWith preserves unchanged fields', () {
      final original = sample();
      final copy = original.copyWith(response: '{"ok":true}');
      expect(copy.response, equals('{"ok":true}'));
      expect(copy.type, equals(original.type));
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

    test('copyWith only changes specified fields', () {
      final original = sample();
      final copy = original.copyWith(value: 'Token');
      expect(copy.value, equals('Token'));
      expect(copy.key, equals(original.key));
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

    test('includes ws_mock_models in output', () {
      final data = MockData(
        id: 2,
        name: 'WS Project',
        host: '0.0.0.0',
        port: 8080,
        mockModels: [],
        wsMockModels: [
          WsMockModel(enable: true, endpoint: '/ws'),
        ],
      );
      final json = data.toJson();
      final wsModels = json['ws_mock_models'] as List;
      expect(wsModels.length, equals(1));
      expect((wsModels.first as Map)['endpoint'], equals('/ws'));
    });

    test('fromJson → toJson round-trip for MockData with models', () {
      final original = MockData(
        id: 5,
        name: 'Round-trip',
        host: 'localhost',
        port: 9090,
        mockModels: [
          MockModel(
            enable: true,
            endpoint: '/ping',
            statusCode: 200,
            responseBody: '{}',
            method: 'GET',
          ),
        ],
      );
      final restored = MockData.fromJson(original.toJson());
      expect(restored.id, equals(5));
      expect(restored.name, equals('Round-trip'));
      expect(restored.mockModels.length, equals(1));
      expect(restored.mockModels.first.endpoint, equals('/ping'));
    });
  });

  // ── WsMockRule ─────────────────────────────────────────────────────────────

  group('WsMockRule', () {
    test('exact match returns true for identical message', () {
      final rule = WsMockRule(id: 'r1', pattern: 'ping', response: 'pong');
      expect(rule.matches('ping'), isTrue);
    });

    test('exact match returns false for different message', () {
      final rule = WsMockRule(id: 'r1', pattern: 'ping', response: 'pong');
      expect(rule.matches('PING'), isFalse);
    });

    test('regex match works correctly', () {
      final rule = WsMockRule(
        id: 'r2',
        pattern: r'^hello.*',
        isRegex: true,
        response: 'world',
      );
      expect(rule.matches('hello world'), isTrue);
      expect(rule.matches('goodbye'), isFalse);
    });

    test('invalid regex returns false gracefully', () {
      final rule = WsMockRule(
        id: 'r3',
        pattern: r'[invalid',
        isRegex: true,
        response: 'oops',
      );
      expect(rule.matches('anything'), isFalse);
    });

    test('toJson → fromJson round-trip is lossless', () {
      final original = WsMockRule(
        id: 'r4',
        pattern: 'subscribe',
        isRegex: false,
        response: '{"type":"subscribed"}',
      );
      final restored = WsMockRule.fromJson(original.toJson());
      expect(restored.id, equals(original.id));
      expect(restored.pattern, equals(original.pattern));
      expect(restored.isRegex, equals(original.isRegex));
      expect(restored.response, equals(original.response));
    });

    test('copyWith changes only specified fields', () {
      final original = WsMockRule(id: 'r5', pattern: 'a', response: 'b');
      final copy = original.copyWith(response: 'c');
      expect(copy.response, equals('c'));
      expect(copy.pattern, equals('a'));
    });
  });

  // ── WsScheduledMessage ─────────────────────────────────────────────────────

  group('WsScheduledMessage', () {
    test('toJson → fromJson round-trip is lossless', () {
      final original = WsScheduledMessage(
        id: 'sm1',
        enabled: true,
        message: '{"heartbeat":true}',
        delayMs: 500,
        repeat: true,
        intervalMs: 3000,
      );
      final restored = WsScheduledMessage.fromJson(original.toJson());
      expect(restored.id, equals('sm1'));
      expect(restored.enabled, isTrue);
      expect(restored.message, equals('{"heartbeat":true}'));
      expect(restored.delayMs, equals(500));
      expect(restored.repeat, isTrue);
      expect(restored.intervalMs, equals(3000));
    });

    test('fromJson uses defaults for missing fields', () {
      final msg = WsScheduledMessage.fromJson({'id': 'sm2'});
      expect(msg.enabled, isTrue);
      expect(msg.message, equals(''));
      expect(msg.delayMs, equals(1000));
      expect(msg.repeat, isFalse);
      expect(msg.intervalMs, equals(5000));
    });

    test('copyWith changes only specified fields', () {
      final original = WsScheduledMessage(
        id: 'sm3',
        message: 'tick',
        delayMs: 1000,
      );
      final copy = original.copyWith(delayMs: 2000);
      expect(copy.delayMs, equals(2000));
      expect(copy.message, equals('tick'));
    });
  });

  // ── WsMockModel ────────────────────────────────────────────────────────────

  group('WsMockModel', () {
    test('toJson → fromJson round-trip preserves all fields', () {
      final original = WsMockModel(
        enable: true,
        endpoint: '/chat',
        onConnectMessage: '{"type":"connected"}',
        rules: [
          WsMockRule(id: 'r1', pattern: 'hello', response: 'hi'),
        ],
        scheduledMessages: [
          WsScheduledMessage(id: 'sm1', message: 'ping', delayMs: 100),
        ],
      );
      final restored = WsMockModel.fromJson(original.toJson());
      expect(restored.enable, isTrue);
      expect(restored.endpoint, equals('/chat'));
      expect(restored.onConnectMessage, equals('{"type":"connected"}'));
      expect(restored.rules.length, equals(1));
      expect(restored.rules.first.pattern, equals('hello'));
      expect(restored.scheduledMessages.length, equals(1));
      expect(restored.scheduledMessages.first.message, equals('ping'));
    });

    test('fromJson uses sensible defaults', () {
      final model = WsMockModel.fromJson({'endpoint': '/ws'});
      expect(model.enable, isFalse);
      expect(model.onConnectMessage, isNull);
      expect(model.rules, isEmpty);
      expect(model.scheduledMessages, isEmpty);
    });

    test('copyWith changes only specified fields', () {
      final original = WsMockModel(enable: true, endpoint: '/ws');
      final copy = original.copyWith(endpoint: '/notifications');
      expect(copy.endpoint, equals('/notifications'));
      expect(copy.enable, isTrue);
    });
  });
}
