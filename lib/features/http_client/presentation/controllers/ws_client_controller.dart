import 'dart:convert';

import 'package:get/get.dart';
import 'package:mockondo/features/http_client/data/models/ws_client_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/v4.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// GetX controller for the WebSocket client feature.
///
/// Manages saved [WsClientItem]s, the active connection, and the message log.
class WsClientController extends GetxController {
  /// All saved WebSocket connections.
  final items = <WsClientItem>[].obs;

  /// Index of the currently selected connection in [items].
  final selectedIndex = 0.obs;

  /// `true` while the WebSocket connection is open.
  final connected = false.obs;

  /// Conversation log for the active connection.
  final messages = <WsMessage>[].obs;

  /// Error message from the last failed connect attempt.
  final errorMessage = RxnString();

  WebSocketChannel? _channel;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  @override
  void onClose() {
    _channel?.sink.close();
    super.onClose();
  }

  // ── Selection ───────────────────────────────────────────────────────────────

  WsClientItem? get selected =>
      items.isEmpty ? null : items[selectedIndex.value];

  void selectItem(int index) {
    if (connected.value) disconnect();
    selectedIndex.value = index;
    messages.clear();
    errorMessage.value = null;
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  void addItem() {
    items.add(WsClientItem(id: UuidV4().generate()));
    selectedIndex.value = items.length - 1;
    messages.clear();
    errorMessage.value = null;
    _save();
  }

  void deleteItem(int index) {
    if (connected.value && selectedIndex.value == index) disconnect();
    items.removeAt(index);
    if (items.isEmpty) {
      selectedIndex.value = 0;
    } else if (selectedIndex.value >= items.length) {
      selectedIndex.value = items.length - 1;
    }
    _save();
  }

  // ── Connection lifecycle ─────────────────────────────────────────────────────

  /// Connects to [selected]'s URL and starts listening for messages.
  Future<void> connect() async {
    final item = selected;
    if (item == null) return;

    final urlStr = item.url.trim();
    if (urlStr.isEmpty) {
      errorMessage.value = 'URL is empty.';
      return;
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null || (!uri.scheme.startsWith('ws'))) {
      errorMessage.value = 'URL must start with ws:// or wss://';
      return;
    }

    errorMessage.value = null;
    messages.clear();

    try {
      // Build headers map from enabled key-value pairs.
      final headers = <String, String>{};
      for (final h in item.headers) {
        if (h.enabled && h.key.isNotEmpty) headers[h.key] = h.value;
      }

      _channel = WebSocketChannel.connect(uri, protocols: const []);
      await _channel!.ready;

      connected.value = true;
      _appendMessage(WsMessage(
        text: '✅ Connected to $urlStr',
        isSent: false,
        time: DateTime.now(),
      ));

      _channel!.stream.listen(
        (data) {
          _appendMessage(WsMessage(
            text: data.toString(),
            isSent: false,
            time: DateTime.now(),
          ));
        },
        onDone: () {
          connected.value = false;
          _appendMessage(WsMessage(
            text: '🔌 Disconnected',
            isSent: false,
            time: DateTime.now(),
          ));
        },
        onError: (e) {
          connected.value = false;
          _appendMessage(WsMessage(
            text: '❌ Error: $e',
            isSent: false,
            time: DateTime.now(),
          ));
        },
      );
    } catch (e) {
      connected.value = false;
      errorMessage.value = e.toString();
    }
  }

  /// Closes the active WebSocket connection.
  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    connected.value = false;
  }

  /// Sends [text] over the active connection.
  void send(String text) {
    if (!connected.value || _channel == null || text.isEmpty) return;
    _channel!.sink.add(text);
    _appendMessage(WsMessage(text: text, isSent: true, time: DateTime.now()));
  }

  void _appendMessage(WsMessage msg) {
    messages.add(msg);
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ws_client_items',
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('ws_client_items');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      items.value = list
          .map((e) => WsClientItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {}
  }

  /// Called by export/import service to flush current state.
  void saveItems() => _save();
}
