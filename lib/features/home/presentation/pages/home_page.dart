import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/log.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/server.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/home/presentation/widgets/endpoint_widget.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // final server = MainServer();
  TextEditingController hostController = TextEditingController();
  TextEditingController portController = TextEditingController();
  bool showLog = false;

  String? _ipAddress;
  List<MockData?> mockModels = [];
  int selectedMockModelIndex = 0;

  @override
  void initState() {
    super.initState();
    _getIpAddress();
    load();
  }

  Future<void> _getIpAddress() async {
    final info = NetworkInfo();
    final wifiIP = await info.getWifiIP(); // IP lokal di jaringan Wi-Fi

    setState(() {
      _ipAddress = wifiIP;
      mockModels[selectedMockModelIndex]?.server?.setLocalIp = _ipAddress ?? '';
    });
  }

  save() async {
    if (mockModels.isEmpty) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'mocks_data',
      jsonEncode(mockModels.map((e) => e?.toJson()).toList()),
    );
    setState(() {});
  }

  load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('mocks_data');

    if (data == null) return;

    mockModels =
        (jsonDecode(data) as List<dynamic>)
            .map((e) => MockData.fromJson(e as Map<String, dynamic>))
            .toList();
    hostController.text = mockModels[selectedMockModelIndex]?.host ?? '';
    portController.text =
        (mockModels[selectedMockModelIndex]?.port ?? 8080).toString();
    setState(() {});
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
    setState(() {});
  }

  removeModel(int index) {
    mockModels.removeAt(index);
    if (selectedMockModelIndex >= index && selectedMockModelIndex > 0) {
      selectedMockModelIndex--;
    }
    if (mockModels.isEmpty) {
      hostController.text = '';
      portController.text = '';
    } else {
      hostController.text = mockModels[selectedMockModelIndex]?.host ?? '';
      portController.text =
          (mockModels[selectedMockModelIndex]?.port ?? 8080).toString();
    }

    Navigator.of(context).pop();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors(context).backgroundDarkness,
      body: Row(
        children: [
          SizedBox(
            width: 200,
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                children: [
                  ...List.generate(
                    mockModels.length,
                    (index) => InkWell(
                      onTap: () {
                        selectedMockModelIndex = index;
                        hostController.text =
                            mockModels[selectedMockModelIndex]?.host ?? '';
                        portController.text =
                            (mockModels[selectedMockModelIndex]?.port ?? 8080)
                                .toString();
                        setState(() {});
                      },
                      onSecondaryTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              backgroundColor:
                                  colors(context).backgroundDarkness,
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CustomTextField(
                                    controller: TextEditingController(
                                      text: mockModels[index]?.name ?? '',
                                    ),
                                    hintText: 'Project Name',
                                    onChanged: (value) {
                                      mockModels[index]?.name = value;
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    removeModel(index);
                                  },
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: colors(context).redDarkness,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Close'),
                                ),
                              ],
                            );
                          },
                        );

                        setState(() {});
                      },
                      child: Container(
                        color:
                            selectedMockModelIndex == index
                                ? AppColors.textD.withValues(alpha: 0.3)
                                : Colors.transparent,
                        height: 50,
                        child: Center(
                          child: Text(
                            mockModels[index]?.name ?? 'Unnamed Project',
                            style: TextStyle(
                              color: AppColors.textD,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton(
                      onPressed: () {
                        createModel();
                      },
                      child: Text('Add Project'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mockModels.isEmpty) ...[
            Expanded(
              child: Center(
                child: Text(
                  'No project available. Please add a new project.',
                  style: TextStyle(color: AppColors.textD, fontSize: 16),
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SizedBox(
                      height: 50,
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: Center(
                                child: CustomTextField(
                                  controller: hostController,
                                  hintText:
                                      'Proxy Target URL : https://example.com',
                                  readOnly:
                                      mockModels[selectedMockModelIndex]
                                          ?.server
                                          ?.isRunning ??
                                      false,
                                  onChanged: (value) async {
                                    mockModels[selectedMockModelIndex]!.host =
                                        value;
                                    await save();
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_right_rounded),
                          Expanded(
                            child: SizedBox(
                              height: 30,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SelectableText(
                                      '$_ipAddress${!(mockModels[selectedMockModelIndex]?.server?.isRunning ?? false) ? '' : ':${mockModels[selectedMockModelIndex]?.server?.port}'}',
                                      style: TextStyle(
                                        color: AppColors.textD,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      'your ip address',
                                      style: TextStyle(
                                        color: AppColors.textD,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // child: Center(child: CustomTextField()),
                            ),
                          ),
                          SizedBox(width: 5),
                          SizedBox(
                            height: 30,
                            width: 100,
                            child: Center(
                              child: CustomTextField(
                                controller: portController,
                                hintText: 'Port',
                                readOnly:
                                    mockModels[selectedMockModelIndex]
                                        ?.server
                                        ?.isRunning ??
                                    false,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (value) async {
                                  mockModels[selectedMockModelIndex]!.port =
                                      int.parse(value.isEmpty ? '8080' : value);
                                  await save();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Divider(thickness: 1),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        ElevatedButton(
                          onPressed:
                              mockModels[selectedMockModelIndex]
                                          ?.server
                                          ?.isRunning ??
                                      false
                                  ? null
                                  : () async {
                                    var m =
                                        mockModels[selectedMockModelIndex]
                                            ?.mockModels ??
                                        [];
                                    m.add(
                                      MockModel(
                                        enable: false,
                                        endpoint: '',
                                        statusCode: 200,
                                        responseBody: '',
                                        method: 'GET',
                                      ),
                                    );
                                    mockModels[selectedMockModelIndex] =
                                        mockModels[selectedMockModelIndex]
                                            ?.copyWith(mockModels: m);
                                    await save();
                                    setState(() {});
                                    log(
                                      mockModels[selectedMockModelIndex]
                                              ?.mockModels
                                              .length
                                              .toString() ??
                                          '',
                                    );
                                  },
                          child: Text('Add Endpoint'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ListView.builder(
                        itemCount:
                            mockModels[selectedMockModelIndex]
                                ?.mockModels
                                .length ??
                            0,
                        itemBuilder: (context, index) {
                          /// Get current mock model
                          final current =
                              mockModels[selectedMockModelIndex]!
                                  .mockModels[index];

                          /// check if there is prior same enabled endpoint with same method
                          final hasPriorSame =
                              mockModels[selectedMockModelIndex]!.mockModels
                                  .sublist(0, index)
                                  .any(
                                    (e) =>
                                        e.enable &&
                                        e.endpoint == current.endpoint &&
                                        e.method == current.method,
                                  );

                          /// determine if this is not the first running endpoint with same method and endpoint
                          final isNotFirstRunning =
                              (mockModels[selectedMockModelIndex]
                                      ?.server
                                      ?.isRunning ??
                                  false) &&
                              hasPriorSame;

                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: EndpointWidget(
                              server:
                                  mockModels[selectedMockModelIndex]!.server!,
                              isNotFirstRunning: isNotFirstRunning,
                              mockModel:
                                  mockModels[selectedMockModelIndex]!
                                      .mockModels[index],
                              onChangedBodyResponse: (value) async {
                                mockModels[selectedMockModelIndex]!
                                    .mockModels[index]
                                    .responseBody = value;
                                await save();
                                setState(() {});
                              },
                              onChangedCheck: (value) async {
                                mockModels[selectedMockModelIndex]!
                                    .mockModels[index]
                                    .enable = value ?? false;
                                await save();
                                setState(() {});
                              },
                              onChangedEndpoint: (value) async {
                                mockModels[selectedMockModelIndex]!
                                    .mockModels[index]
                                    .endpoint = value;
                                await save();
                                setState(() {});
                              },
                              onChangedStatusCode: (value) async {
                                mockModels[selectedMockModelIndex]!
                                    .mockModels[index]
                                    .statusCode = int.parse(value);
                                await save();
                                setState(() {});
                              },
                              onChangedDelay: (value) async {
                                mockModels[selectedMockModelIndex]!
                                    .mockModels[index]
                                    .delay = int.parse(value);
                                await save();
                                setState(() {});
                              },
                              onChangedHeaderResponse: (value) async {
                                mockModels[selectedMockModelIndex]!
                                    .mockModels[index]
                                    .responseHeader = parseHeader(value);
                                await save();
                                setState(() {});
                              },
                              onChangedMethod: (value) async {
                                mockModels[selectedMockModelIndex]!
                                    .mockModels[index]
                                    .method = value;
                                await save();
                                setState(() {});
                              },
                              onDelete: () async {
                                mockModels[selectedMockModelIndex]!.mockModels
                                    .removeAt(index);
                                await save();
                                setState(() {});
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Visibility(
                    visible: showLog,
                    child: Container(
                      height: 200,
                      width: MediaQuery.sizeOf(context).width,
                      color: AppColors.terminalD,
                      child: ValueListenableBuilder<List<LogModel>>(
                        valueListenable:
                            mockModels[selectedMockModelIndex]
                                ?.server
                                ?.logService
                                .logs ??
                            ValueNotifier<List<LogModel>>([]),
                        builder: (context, logs, _) {
                          return ListView.builder(
                            itemCount: logs.length,
                            physics: ClampingScrollPhysics(),
                            itemBuilder: (context, index) {
                              return SelectableText(logs[index].log);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  Container(
                    height: 25,
                    width: MediaQuery.sizeOf(context).width,
                    color: colors(context).secondaryDarkness,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: () {
                              showLog = !showLog;
                              setState(() {});
                            },
                            child: SizedBox(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.terminal_rounded, size: 15),
                                  SizedBox(width: 5),
                                  Text('log', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 15),
                          Visibility(
                            visible:
                                (mockModels[selectedMockModelIndex]?.mockModels
                                        .where((e) => e.enable)
                                        .length ??
                                    0) !=
                                0,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_tethering, size: 15),
                                SizedBox(width: 5),
                                Text(
                                  '${mockModels[selectedMockModelIndex]?.mockModels.where((e) => e.enable).length} ${(mockModels[selectedMockModelIndex]?.server?.isRunning ?? false) ? 'running...' : 'ready to mock'}',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton:
          mockModels.isEmpty
              ? null
              : FloatingActionButton(
                backgroundColor:
                    (mockModels[selectedMockModelIndex]?.server?.isRunning ??
                            false)
                        ? Colors.red
                        : colors(context).greenDarkness,
                onPressed: () async {
                  mockModels[selectedMockModelIndex]?.server?.setHost =
                      mockModels[selectedMockModelIndex]?.host ?? '';
                  mockModels[selectedMockModelIndex]?.server?.setPort =
                      mockModels[selectedMockModelIndex]?.port ?? 8080;
                  if (portController.text.isEmpty) {
                    portController.text =
                        mockModels[selectedMockModelIndex]!.server!.port
                            .toString();
                  }

                  mockModels[selectedMockModelIndex]?.server?.clearRouters();

                  if (mockModels[selectedMockModelIndex]?.server?.isRunning ??
                      false) {
                    await mockModels[selectedMockModelIndex]?.server?.stop();
                    setState(() {});
                    return;
                  }

                  for (var mockModel
                      in mockModels[selectedMockModelIndex]?.mockModels ??
                          <MockModel>[]) {
                    if (!mockModel.enable) continue;
                    // Tambah router baru
                    final customRouter = getRouter(mockModel.method, mockModel);
                    mockModels[selectedMockModelIndex]?.server?.addRouter(
                      customRouter,
                    );
                  }

                  setState(() {});
                  await mockModels[selectedMockModelIndex]?.server?.run();
                  await save();
                },
                child: Icon(
                  (mockModels[selectedMockModelIndex]?.server?.isRunning ??
                          false)
                      ? Icons.stop
                      : Icons.play_arrow,
                  color: Colors.white,
                ),
              ),
    );
  }

  shelf_router.Router getRouter(String method, MockModel mockModel) {
    switch (method) {
      case 'GET':
        return shelf_router.Router()
          ..get(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: mockModel.responseBody,
            );
          });
      case 'POST':
        return shelf_router.Router()
          ..post(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: mockModel.responseBody,
            );
          });
      case 'PUT':
        return shelf_router.Router()
          ..put(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: mockModel.responseBody,
            );
          });
      case 'PATCH':
        return shelf_router.Router()
          ..patch(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: mockModel.responseBody,
            );
          });
      case 'DELETE':
        return shelf_router.Router()
          ..delete(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response(
              mockModel.statusCode,
              headers: mockModel.responseHeader,
              body: mockModel.responseBody,
            );
          });
      default:
        return shelf_router.Router()
          ..get(mockModel.endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response.ok('This is custom route');
          });
    }
  }

  Map<String, Object> parseHeader(String jsonString) {
    final decoded = jsonDecode(jsonString);

    if (decoded is Map<String, dynamic>) {
      return decoded.map((key, value) {
        if (value is Object) {
          return MapEntry(key, value);
        } else {
          throw FormatException('Value for key "$key" is not an Object.');
        }
      });
    } else {
      throw FormatException('Invalid JSON format. Expected a JSON object.');
    }
  }
}
