import 'dart:convert';

import 'package:get/get.dart';
import 'package:mockondo/core/interpolation.dart';
import 'package:mockondo/features/http_client/data/models/ws_client_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/v4.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// GetX controller for the WebSocket client feature.
///
/// Each [WsClientItem] can have its own independent connection — switching
/// between items does NOT disconnect the active one.
class WsClientController extends GetxController {
  /// All saved WebSocket connections.
  final items = <WsClientItem>[].obs;

  /// Index of the currently selected connection in [items].
  final selectedIndex = 0.obs;

  /// `true` while the SELECTED connection is open.
  final connected = false.obs;

  /// Conversation log for the SELECTED connection.
  final messages = <WsMessage>[].obs;

  /// Error message from the last failed connect attempt (selected item).
  final errorMessage = RxnString();

  /// Incremented whenever any connection opens or closes — lets the sidebar
  /// dots react without subscribing to every individual channel.
  final connVersion = 0.obs;

  // Per-connection channels (keyed by WsClientItem.id)
  final _channels = <String, WebSocketChannel>{};

  // Per-connection message cache (keyed by WsClientItem.id)
  final _perMessages = <String, List<WsMessage>>{};

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  @override
  void onClose() {
    for (final ch in _channels.values) {
      ch.sink.close();
    }
    _channels.clear();
    super.onClose();
  }

  // ── Selection ───────────────────────────────────────────────────────────────

  WsClientItem? get selected =>
      items.isEmpty ? null : items[selectedIndex.value];

  /// Returns whether [id] has an active connection.
  bool isItemConnected(String id) => _channels.containsKey(id);

  /// Switches the selected item WITHOUT disconnecting the current one.
  void selectItem(int index) {
    // Save current messages to cache before switching
    final currentId = selected?.id;
    if (currentId != null) {
      _perMessages[currentId] = List.from(messages);
    }

    selectedIndex.value = index;
    errorMessage.value = null;

    // Restore state for newly selected item
    final newId = selected?.id;
    if (newId != null) {
      messages.value = List.from(_perMessages[newId] ?? []);
      connected.value = _channels.containsKey(newId);
    } else {
      messages.clear();
      connected.value = false;
    }
  }

  // ── CRUD ────────────────────────────────────────────────────────────────────

  void addItem() {
    // Save current messages before switching
    final currentId = selected?.id;
    if (currentId != null) {
      _perMessages[currentId] = List.from(messages);
    }

    items.add(WsClientItem(id: UuidV4().generate()));
    selectedIndex.value = items.length - 1;
    messages.clear();
    connected.value = false;
    errorMessage.value = null;
    _save();
  }

  void deleteItem(int index) {
    final item = items[index];

    // Disconnect and clean up that item's resources
    _channels[item.id]?.sink.close();
    _channels.remove(item.id);
    _perMessages.remove(item.id);
    connVersion.value++;

    items.removeAt(index);

    if (items.isEmpty) {
      selectedIndex.value = 0;
      messages.clear();
      connected.value = false;
    } else {
      if (selectedIndex.value >= items.length) {
        selectedIndex.value = items.length - 1;
      }
      final newId = selected?.id;
      if (newId != null) {
        messages.value = List.from(_perMessages[newId] ?? []);
        connected.value = _channels.containsKey(newId);
      }
    }
    _save();
  }

  // ── Connection lifecycle ─────────────────────────────────────────────────────

  /// Connects the currently selected item.
  Future<void> connect() async {
    final item = selected;
    if (item == null) return;
    final id = item.id;

    // Interpolate URL so ${customdata.*} placeholders are resolved
    final urlStr = Interpolation()
        .excute(before: item.url.trim(), data: '')
        .replaceAll('"', '');
    if (urlStr.isEmpty) {
      errorMessage.value = 'URL is empty.';
      return;
    }

    final uri = Uri.tryParse(urlStr);
    if (uri == null || !uri.scheme.startsWith('ws')) {
      errorMessage.value = 'URL must start with ws:// or wss://';
      return;
    }

    errorMessage.value = null;

    // Clear previous messages for this connection (fresh connect)
    _perMessages[id] = [];
    if (selected?.id == id) messages.clear();

    try {
      final headers = <String, String>{};
      for (final h in item.headers) {
        if (h.enabled && h.key.isNotEmpty) headers[h.key] = h.value;
      }

      final channel = WebSocketChannel.connect(uri, protocols: const []);
      await channel.ready;

      _channels[id] = channel;
      connVersion.value++;

      if (selected?.id == id) connected.value = true;

      _addMessage(id, WsMessage(
        text: '✅ Connected to $urlStr',
        isSent: false,
        time: DateTime.now(),
      ));

      channel.stream.listen(
        (data) {
          _addMessage(id, WsMessage(
            text: data.toString(),
            isSent: false,
            time: DateTime.now(),
          ));
        },
        onDone: () {
          _channels.remove(id);
          connVersion.value++;
          _addMessage(id, WsMessage(
            text: '🔌 Disconnected',
            isSent: false,
            time: DateTime.now(),
          ));
          if (selected?.id == id) connected.value = false;
        },
        onError: (e) {
          _channels.remove(id);
          connVersion.value++;
          _addMessage(id, WsMessage(
            text: '❌ Error: $e',
            isSent: false,
            time: DateTime.now(),
          ));
          if (selected?.id == id) connected.value = false;
        },
      );
    } catch (e) {
      _channels.remove(id);
      connVersion.value++;
      if (selected?.id == id) {
        connected.value = false;
        errorMessage.value = e.toString();
      }
    }
  }

  /// Disconnects the currently selected item.
  void disconnect() {
    final id = selected?.id;
    if (id == null) return;
    _channels[id]?.sink.close();
    _channels.remove(id);
    connVersion.value++;
    connected.value = false;
  }

  /// Sends [text] over the currently selected connection.
  ///
  /// All `${...}` interpolation placeholders are resolved before sending.
  void send(String text) {
    final id = selected?.id;
    if (id == null || text.isEmpty) return;
    final channel = _channels[id];
    if (channel == null) return;
    final resolved = Interpolation().excute(before: text, data: '');
    channel.sink.add(resolved);
    _addMessage(id, WsMessage(text: resolved, isSent: true, time: DateTime.now()));
  }

  /// Adds [msg] to the per-connection cache and, if [id] is currently
  /// selected, also appends it to the reactive [messages] list.
  void _addMessage(String id, WsMessage msg) {
    _perMessages.putIfAbsent(id, () => []).add(msg);
    if (selected?.id == id) messages.add(msg);
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
