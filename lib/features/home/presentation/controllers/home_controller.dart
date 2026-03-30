import 'dart:convert';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/server.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Root GetX controller for the mock server feature.
///
/// Manages the list of [MockData] projects, the currently selected project,
/// custom data entries, and server lifecycle. All data is persisted to
/// [SharedPreferences] and reloaded on startup.
class HomeController extends GetxController {
  /// Host input for the currently selected project.
  final hostController = TextEditingController().obs;

  /// Port input for the currently selected project.
  final portController = TextEditingController().obs;

  /// Whether the terminal log panel is visible.
  final showLog = false.obs;

  /// The device's current Wi-Fi IP address, used as the server bind address.
  final ipAddress = ''.obs;

  /// All loaded mock projects. A `null` slot should never appear in practice
  /// but is retained to avoid index shifting issues during async operations.
  final mockModels = <MockData?>[].obs;

  /// Index of the project that is currently visible in the editor.
  final selectedMockModelIndex = 0.obs;

  /// The custom-data key that is highlighted in the Custom Data panel.
  final selectedCustomDataKey = ''.obs;

  /// The custom-data value that is highlighted in the Custom Data panel.
  final selectedCustomDataValue = RxnString();

  /// User-defined data store: map of `key → list of string values`.
  /// Persisted to SharedPreferences as JSON.
  final customData = <String, RxList<String>>{}.obs;

  @override
  void onInit() {
    getIpAddress();
    load();
    loadCustomData();
    super.onInit();
  }

  // ── Custom data ─────────────────────────────────────────────────────────────

  /// Loads custom data from SharedPreferences and pre-selects the first key.
  loadCustomData() {
    getCustomData();

    if (customData.isNotEmpty) {
      selectedCustomDataKey.value = customData.keys.first;
    }
  }

  // ── Project management ──────────────────────────────────────────────────────

  /// Switches the active project to [index] and updates the host/port inputs.
  changeProject(int index) {
    selectedMockModelIndex.value = index;
    final mock = mockModels[index];
    hostController.value.text = mock?.host ?? '';
    portController.value.text = (mock?.port ?? 8080).toString();
    update();
  }

  /// Reads the device's current Wi-Fi IP and stores it in [ipAddress].
  /// Also pushes the IP to the active server so it binds on the correct address.
  Future<void> getIpAddress() async {
    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP();

    ipAddress.value = wifiIP ?? '';
    if (mockModels.isEmpty) return;
    mockModels[selectedMockModelIndex.value]?.server?.setLocalIp =
        ipAddress.value;
  }

  // ── Persistence ─────────────────────────────────────────────────────────────

  /// Wipes all SharedPreferences data. Used for debugging only.
  clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Debug helper: reads and logs all stored mock project data.
  getAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('mocks_data');

    if (data == null) return;

    final res =
        (jsonDecode(data) as List<dynamic>)
            .map((e) => MockData.fromJson(e as Map<String, dynamic>))
            .toList();
    log(res.map((e) => jsonEncode(e.toJson())).toList().toString());
  }

  /// Serialises all projects to JSON and writes them to SharedPreferences.
  save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'mocks_data',
      jsonEncode(mockModels.map((e) => e?.toJson()).toList()),
    );
  }

  /// Loads saved projects from SharedPreferences and restores the UI state.
  load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('mocks_data');

    if (data == null) return;

    mockModels.value =
        (jsonDecode(data) as List<dynamic>)
            .map((e) => MockData.fromJson(e as Map<String, dynamic>))
            .toList();
    hostController.value.text =
        mockModels[selectedMockModelIndex.value]?.host ?? '';
    portController.value.text =
        (mockModels[selectedMockModelIndex.value]?.port ?? 8080).toString();

    if (mockModels.isNotEmpty) {
      selectedMockModelIndex.value = 0;
    }
  }

  // ── Endpoint / rule helpers ─────────────────────────────────────────────────

  /// Creates a new project with a unique ID and an auto-incremented port
  /// (starting at 8081, 8082, …).
  createModel() {
    final id = mockModels.isNotEmpty ? mockModels.last!.id + 1 : 1;
    final port = 8080 + id;

    mockModels.add(
      MockData(
        id: id,
        name: 'Project $id',
        host: '',
        port: port,
        mockModels: [],
        server: MainServer(),
      ),
    );

    getIpAddress();
    hostController.value.text = '';
    portController.value.text = port.toString();
    save();
  }

  /// Stops and removes the project at [index].
  /// Adjusts [selectedMockModelIndex] to stay in range.
  removeModel(int index) {
    mockModels[index]?.server?.stop();
    mockModels.removeAt(index);
    if (selectedMockModelIndex >= index && selectedMockModelIndex > 0) {
      selectedMockModelIndex.value--;
    }

    if (mockModels.isEmpty) {
      hostController.value.text = '';
      portController.value.text = '';
    } else {
      hostController.value.text =
          mockModels[selectedMockModelIndex.value]?.host ?? '';
      portController.value.text =
          (mockModels[selectedMockModelIndex.value]?.port ?? 8080).toString();
    }

    save();
  }

  /// Returns the pagination [Rules] for the given endpoint, or `null` if none.
  Rules? isPagination(int endpointIndex) {
    if ((mockModels[selectedMockModelIndex.value]!
                .mockModels[endpointIndex]
                .rules ??
            [])
        .isEmpty) {
      return null;
    }

    return mockModels[selectedMockModelIndex.value]
        ?.mockModels[endpointIndex]
        .rules
        ?.firstWhereOrNull((rule) => rule.type == RulesType.pagination);
  }

  /// Removes the pagination rule from an endpoint if one exists.
  removePagination(int endpointIndex) {
    final rules =
        mockModels[selectedMockModelIndex.value]
            ?.mockModels[endpointIndex]
            .rules ??
        [];

    if (isPagination(endpointIndex) != null) {
      rules.removeWhere((rule) => rule.type == RulesType.pagination);
    }
  }

  /// Saves or replaces the pagination rule for [endpointIndex].
  /// [response] is the per-item body template; [paginationParams] holds
  /// the limit/offset configuration.
  setPagination(
    int endpointIndex,
    String response,
    PaginationParams paginationParams,
  ) {
    final rules =
        mockModels[selectedMockModelIndex.value]
            ?.mockModels[endpointIndex]
            .rules ??
        [];

    // Replace any existing pagination rule (there can only be one).
    if (isPagination(endpointIndex) != null) {
      rules.removeWhere((rule) => rule.type == RulesType.pagination);
    }

    rules.add(
      Rules(
        type: RulesType.pagination,
        response: response,
        rules: paginationParams.toJson(),
      ),
    );

    mockModels[selectedMockModelIndex.value]?.mockModels[endpointIndex].rules =
        rules;
  }

  // ── WebSocket endpoint helpers ──────────────────────────────────────────────

  /// Adds a new disabled WebSocket endpoint to the active project.
  void addWsEndpoint() {
    final project = mockModels[selectedMockModelIndex.value];
    if (project == null) return;
    project.wsMockModels.add(WsMockModel(enable: false, endpoint: '/ws'));
    save();
  }

  /// Removes the WebSocket endpoint at [index] from the active project.
  void removeWsEndpoint(int index) {
    mockModels[selectedMockModelIndex.value]?.wsMockModels.removeAt(index);
    save();
  }

  /// Persists updated configuration for a WebSocket endpoint.
  void saveWsEndpoint(int index, WsMockModel updated) {
    mockModels[selectedMockModelIndex.value]?.wsMockModels[index] = updated;
    save();
  }

  /// Returns all [RulesType.response] rules for the given endpoint.
  List<Rules> getResponseRules(int endpointIndex) {
    return (mockModels[selectedMockModelIndex.value]
                ?.mockModels[endpointIndex]
                .rules ??
            [])
        .where((r) => r.type == RulesType.response)
        .toList();
  }

  /// Inserts [rule] or replaces the existing rule with the same `id` in
  /// [rules['id']]. Persists after the update.
  void addOrUpdateResponseRule(int endpointIndex, Rules rule) {
    final allRules =
        mockModels[selectedMockModelIndex.value]
            ?.mockModels[endpointIndex]
            .rules ??
        [];

    final idx = allRules.indexWhere(
      (r) => r.type == RulesType.response && r.rules['id'] == rule.rules['id'],
    );

    if (idx >= 0) {
      allRules[idx] = rule;
    } else {
      allRules.add(rule);
    }

    mockModels[selectedMockModelIndex.value]?.mockModels[endpointIndex].rules =
        allRules;
    save();
  }

  /// Deletes the response rule identified by [ruleId] from the endpoint.
  void removeResponseRule(int endpointIndex, String ruleId) {
    final allRules =
        mockModels[selectedMockModelIndex.value]
            ?.mockModels[endpointIndex]
            .rules ??
        [];
    allRules.removeWhere(
      (r) => r.type == RulesType.response && r.rules['id'] == ruleId,
    );
    mockModels[selectedMockModelIndex.value]?.mockModels[endpointIndex].rules =
        allRules;
    save();
  }

  /// Updates the response header for a single endpoint in-memory only.
  /// Call [saveAllResponseConfig] to also flush to disk.
  saveResponseHeader(
    int endpointIndex,
    Map<String, Object>? responseHeader,
  ) async {
    mockModels[selectedMockModelIndex.value]!
        .mockModels[endpointIndex]
        .responseHeader = responseHeader;
  }

  /// Updates the response body for a single endpoint in-memory only.
  /// Call [saveAllResponseConfig] to also flush to disk.
  saveResponseBody(int endpointIndex, String responseBody) async {
    mockModels[selectedMockModelIndex.value]!
        .mockModels[endpointIndex]
        .responseBody = responseBody;
  }

  /// Saves both the response header and body for an endpoint, then persists
  /// the whole project list to SharedPreferences.
  saveAllResponseConfig({
    required int endpointIndex,
    Map<String, Object>? responseHeader,
    required String responseBody,
  }) async {
    await saveResponseHeader(endpointIndex, responseHeader);
    await saveResponseBody(endpointIndex, responseBody);
    await save();
  }

  /// Returns `true` if the active project's server is currently running.
  bool serverIsRunning() {
    if (mockModels.isEmpty) return false;
    return mockModels[selectedMockModelIndex.value]?.server?.isRunning ?? false;
  }

  /// Serialises [customData] to JSON and writes it to SharedPreferences.
  saveCustomData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(customData.toJson());
    await prefs.setString('custom_data', data);
  }

  /// Loads the custom data store from SharedPreferences.
  getCustomData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('custom_data');

    final Map<String, dynamic> s = jsonDecode(data ?? '');
    customData.value = s.map(
      (key, value) => MapEntry(key, RxList<String>.from(value)),
    );
  }
}

// ── Pagination helpers ──────────────────────────────────────────────────────────

/// Specifies how the offset/page parameter is interpreted by the
/// pagination engine.
enum OffsetType {
  /// Absolute item offset (e.g. `offset=20`).
  offset,

  /// Page number (e.g. `page=2`); the engine multiplies by limit internally.
  page,
}

/// Configuration for a pagination rule, stored inside [Rules.rules].
class PaginationParams {
  /// Fixed page size override (unused when the client supplies the limit param).
  final int? customLimit;

  /// Query parameter name that carries the page size (e.g. `"limit"`).
  final String? limitParam;

  /// Fixed offset override.
  final int? customOffset;

  /// Query parameter name that carries the page / offset (e.g. `"page"`).
  final String? offsetParam;

  final OffsetType? offsetType;

  /// Total number of items in the dataset.
  final int max;

  PaginationParams({
    this.customLimit,
    this.limitParam,
    this.customOffset,
    required this.max,
    this.offsetParam,
    this.offsetType,
  });

  Map<String, dynamic> toJson() {
    return {
      'custom_limit': customLimit,
      'limit_param': limitParam,
      'custom_offset': customOffset,
      'offset_param': offsetParam,
      'offset_type': offsetType,
      'max': max,
    };
  }

  factory PaginationParams.fromJson(Map<String, dynamic> json) {
    return PaginationParams(
      customLimit: json['custom_limit'] as int? ?? 0,
      limitParam: json['limit_param'] as String?,
      customOffset: json['custom_offset'] as int?,
      offsetParam: json['offset_param'] as String?,
      offsetType: OffsetType.values.firstWhere(
        (e) => e.toString().split('.').last == json['offset_type'],
      ),
      max: json['max'] as int? ?? 0,
    );
  }
}
