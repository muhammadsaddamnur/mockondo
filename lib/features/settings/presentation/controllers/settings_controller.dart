import 'package:get/get.dart';
import 'package:mockondo/core/remote_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the Remote Server settings and lifecycle.
///
/// Persists the enabled flag, port, and optional API key to SharedPreferences.
/// Starts / stops the [RemoteServer] when the toggle changes.
class SettingsController extends GetxController {
  static const _kEnabled = 'remote_server_enabled';
  static const _kPort = 'remote_server_port';
  static const _kApiKey = 'remote_server_api_key';

  final enabled = false.obs;
  final port = 3131.obs;
  final apiKey = ''.obs;
  final isRunning = false.obs;
  final errorMessage = RxnString();

  final _server = RemoteServer();

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  @override
  void onClose() {
    _server.stop();
    super.onClose();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // enabled.value = prefs.getBool(_kEnabled) ?? false;
    port.value = prefs.getInt(_kPort) ?? 3131;
    apiKey.value = prefs.getString(_kApiKey) ?? '';

    if (enabled.value) {
      await _startServer();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled.value);
    await prefs.setInt(_kPort, port.value);
    await prefs.setString(_kApiKey, apiKey.value);
  }

  // ── Server lifecycle ──────────────────────────────────────────────────────

  Future<void> _startServer() async {
    errorMessage.value = null;
    try {
      await _server.start(port.value, apiKey: apiKey.value);
      isRunning.value = true;
    } catch (e) {
      errorMessage.value = 'Failed to start remote server: $e';
      isRunning.value = false;
      enabled.value = false;
      await _persist();
    }
  }

  Future<void> _stopServer() async {
    await _server.stop();
    isRunning.value = false;
  }

  // ── Public actions ────────────────────────────────────────────────────────

  Future<void> toggleEnabled(bool value) async {
    enabled.value = value;
    await _persist();
    if (value) {
      await _startServer();
    } else {
      await _stopServer();
    }
  }

  Future<void> updatePort(int newPort) async {
    port.value = newPort;
    await _persist();
    if (isRunning.value) {
      await _stopServer();
      await _startServer();
    }
  }

  Future<void> updateApiKey(String newKey) async {
    apiKey.value = newKey;
    await _persist();
    if (isRunning.value) {
      await _stopServer();
      await _startServer();
    }
  }

  Future<void> restart() async {
    await _stopServer();
    if (enabled.value) {
      await _startServer();
    }
  }
}
