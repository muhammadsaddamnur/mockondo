import 'package:mockondo/features/http_client/data/models/http_client_model.dart';

// ── WsClientItem ──────────────────────────────────────────────────────────────

/// A saved WebSocket connection in the WS client sidebar.
class WsClientItem {
  final String id;
  String name;
  String url;

  /// Optional headers sent with the WebSocket upgrade request.
  List<KeyValuePair> headers;

  WsClientItem({
    required this.id,
    this.name = 'New Connection',
    this.url = '',
    List<KeyValuePair>? headers,
  }) : headers = headers ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'url': url,
    'headers': headers.map((e) => e.toJson()).toList(),
  };

  factory WsClientItem.fromJson(Map<String, dynamic> json) => WsClientItem(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? 'New Connection',
    url: json['url'] as String? ?? '',
    headers:
        (json['headers'] as List<dynamic>?)
            ?.map((e) => KeyValuePair.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

// ── WsMessage ─────────────────────────────────────────────────────────────────

/// A single entry in the WebSocket conversation log.
class WsMessage {
  final String text;

  /// `true` = sent by the client, `false` = received from the server.
  final bool isSent;

  final DateTime time;

  WsMessage({required this.text, required this.isSent, required this.time});
}
