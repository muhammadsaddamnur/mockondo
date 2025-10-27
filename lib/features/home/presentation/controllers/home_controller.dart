import 'dart:convert';
import 'dart:developer';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get/state_manager.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/server.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeController extends GetxController {
  final hostController = TextEditingController();
  final portController = TextEditingController();
  final showLog = false.obs;
  final ipAddress = ''.obs;
  final mockModels = <MockData?>[].obs;
  final selectedMockModelIndex = 0.obs;

  @override
  void onInit() {
    _getIpAddress();
    load();
    super.onInit();
  }

  Future<void> _getIpAddress() async {
    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP(); // IP lokal di jaringan Wi-Fi

    ipAddress.value = wifiIP ?? '';
    if (mockModels.isEmpty) return;
    mockModels[selectedMockModelIndex.value]?.server?.setLocalIp =
        ipAddress.value;
  }

  clearAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.clear();
  }

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

  save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'mocks_data',
      jsonEncode(mockModels.map((e) => e?.toJson()).toList()),
    );
  }

  load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('mocks_data');

    if (data == null) return;

    mockModels.value =
        (jsonDecode(data) as List<dynamic>)
            .map((e) => MockData.fromJson(e as Map<String, dynamic>))
            .toList();
    hostController.text = mockModels[selectedMockModelIndex.value]?.host ?? '';
    portController.text =
        (mockModels[selectedMockModelIndex.value]?.port ?? 8080).toString();

    if (mockModels.isNotEmpty) {
      selectedMockModelIndex.value = 0;
    }
  }

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

    _getIpAddress();
    hostController.text = '';
    portController.text = port.toString();
    save();
  }

  removeModel(int index) {
    mockModels[index]?.server?.stop();
    mockModels.removeAt(index);
    if (selectedMockModelIndex >= index && selectedMockModelIndex > 0) {
      selectedMockModelIndex.value--;
    }

    if (mockModels.isEmpty) {
      hostController.text = '';
      portController.text = '';
    } else {
      hostController.text =
          mockModels[selectedMockModelIndex.value]?.host ?? '';
      portController.text =
          (mockModels[selectedMockModelIndex.value]?.port ?? 8080).toString();
    }

    save();
  }

  Rules? isPagination(int endpointIndex) {
    if ((mockModels[selectedMockModelIndex.value]!
                .mockModels[endpointIndex]
                .rules ??
            [])
        .isEmpty) {
      return null;
    }

    final s = mockModels[selectedMockModelIndex.value]
        ?.mockModels[endpointIndex]
        .rules
        ?.firstWhere((rule) => rule.type == RulesType.pagination);
    return s;
  }

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

  saveResponseHeader(
    int endpointIndex,
    Map<String, Object>? responseHeader,
  ) async {
    mockModels[selectedMockModelIndex.value]!
        .mockModels[endpointIndex]
        .responseHeader = responseHeader;
    // await save();
  }

  saveResponseBody(int endpointIndex, String responseBody) async {
    mockModels[selectedMockModelIndex.value]!
        .mockModels[endpointIndex]
        .responseBody = responseBody;
    // await save();
  }

  saveAllResponseConfig({
    required int endpointIndex,
    Map<String, Object>? responseHeader,
    required String responseBody,
  }) async {
    await saveResponseHeader(endpointIndex, responseHeader);
    await saveResponseBody(endpointIndex, responseBody);
    await save();
  }

  bool serverIsRunning() {
    if (mockModels.isEmpty) return false;
    return mockModels[selectedMockModelIndex.value]?.server?.isRunning ?? false;
  }
}

class PaginationParams {
  final int? customLimit;
  final String? limitParam;
  final int? customOffset;
  final String? offsetParam;
  final int max;

  PaginationParams({
    this.customLimit,
    this.limitParam,
    this.customOffset,
    required this.max,
    this.offsetParam,
  });

  Map<String, dynamic> toJson() {
    return {
      'custom_limit': customLimit,
      'limit_param': limitParam,
      'custom_offset': customOffset,
      'offset_param': offsetParam,
      'max': max,
    };
  }

  factory PaginationParams.fromJson(Map<String, dynamic> json) {
    return PaginationParams(
      customLimit: json['custom_limit'] as int? ?? 0,
      limitParam: json['limit_param'] as String?,
      customOffset: json['custom_offset'] as int?,
      offsetParam: json['offset_param'] as String?,
      max: json['max'] as int? ?? 0,
    );
  }
}
