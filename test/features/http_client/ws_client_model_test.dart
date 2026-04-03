import 'package:flutter_test/flutter_test.dart';
import 'package:mockondo/features/http_client/data/models/ws_client_model.dart';
import 'package:mockondo/features/http_client/data/models/http_client_model.dart';

void main() {
  // ── WsClientItem ───────────────────────────────────────────────────────────

  group('WsClientItem', () {
    test('defaults to empty url and no headers', () {
      final item = WsClientItem(id: 'ws-1');
      expect(item.name, equals('New Connection'));
      expect(item.url, equals(''));
      expect(item.headers, isEmpty);
    });

    test('toJson → fromJson round-trip is lossless', () {
      final original = WsClientItem(
        id: 'ws-2',
        name: 'Chat Server',
        url: 'ws://localhost:8080/chat',
        headers: [
          KeyValuePair(key: 'Authorization', value: 'Bearer token'),
          KeyValuePair(key: 'X-Client-Id', value: '42'),
        ],
      );
      final restored = WsClientItem.fromJson(original.toJson());
      expect(restored.id, equals('ws-2'));
      expect(restored.name, equals('Chat Server'));
      expect(restored.url, equals('ws://localhost:8080/chat'));
      expect(restored.headers.length, equals(2));
      expect(restored.headers.first.key, equals('Authorization'));
      expect(restored.headers.first.value, equals('Bearer token'));
    });

    test('fromJson uses defaults for missing fields', () {
      final item = WsClientItem.fromJson({'id': 'ws-3'});
      expect(item.name, equals('New Connection'));
      expect(item.url, equals(''));
      expect(item.headers, isEmpty);
    });

    test('toJson serialises headers as a list', () {
      final item = WsClientItem(
        id: 'ws-4',
        headers: [KeyValuePair(key: 'Key', value: 'Val')],
      );
      final json = item.toJson();
      expect(json['headers'], isA<List>());
      expect((json['headers'] as List).length, equals(1));
    });

    test('fromJson handles empty headers list', () {
      final item = WsClientItem.fromJson({
        'id': 'ws-5',
        'name': 'Test',
        'url': 'ws://test',
        'headers': <dynamic>[],
      });
      expect(item.headers, isEmpty);
    });

    test('disabled headers are preserved across round-trip', () {
      final original = WsClientItem(
        id: 'ws-6',
        headers: [KeyValuePair(key: 'X-Disabled', value: 'yes', enabled: false)],
      );
      final restored = WsClientItem.fromJson(original.toJson());
      expect(restored.headers.first.enabled, isFalse);
    });
  });

  // ── WsMessage ──────────────────────────────────────────────────────────────

  group('WsMessage', () {
    test('stores text, isSent, and time correctly', () {
      final now = DateTime.now();
      final msg = WsMessage(text: 'hello', isSent: true, time: now);
      expect(msg.text, equals('hello'));
      expect(msg.isSent, isTrue);
      expect(msg.time, equals(now));
    });

    test('received messages have isSent = false', () {
      final msg = WsMessage(text: 'response', isSent: false, time: DateTime.now());
      expect(msg.isSent, isFalse);
    });
  });
}
