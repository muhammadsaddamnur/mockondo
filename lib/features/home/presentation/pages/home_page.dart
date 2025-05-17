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
  final server = MainServer();
  TextEditingController hostController = TextEditingController();
  TextEditingController portController = TextEditingController();
  bool showLog = false;

  String? _ipAddress;
  MockData? mockModel = MockData(host: '', port: 8080, mockModels: []);

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
      server.setLocalIp = _ipAddress ?? '';
    });
  }

  save() async {
    if (mockModel == null) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_data', jsonEncode(mockModel?.toJson()));
    setState(() {});
  }

  load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('local_data');

    if (data == null) return;

    mockModel = MockData.fromJson(jsonDecode(data));
    hostController.text = mockModel?.host ?? '';
    portController.text = (mockModel?.port ?? 8080).toString();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors(context).backgroundDarkness,
      body: Column(
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
                          hintText: 'Proxy Target URL : https://example.com',
                          readOnly: server.isRunning,
                          onChanged: (value) async {
                            mockModel!.host = value;
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
                              '$_ipAddress${!server.isRunning ? '' : ':${server.server?.port}'}',
                              style: TextStyle(
                                color: AppColors.textD,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'your local ip address',
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
                        readOnly: server.isRunning,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) async {
                          mockModel!.port = int.parse(
                            value.isEmpty ? '8080' : value,
                          );
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
                      server.isRunning
                          ? null
                          : () async {
                            var m = mockModel?.mockModels ?? [];
                            m.add(
                              MockModel(
                                enable: false,
                                endpoint: '',
                                statusCode: 200,
                                responseBody: '',
                                method: 'GET',
                              ),
                            );
                            mockModel = mockModel?.copyWith(mockModels: m);
                            await save();
                            setState(() {});
                            log(mockModel?.mockModels.length.toString() ?? '');
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
                itemCount: mockModel?.mockModels.length ?? 0,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: EndpointWidget(
                      server: server,
                      mockModel: mockModel!.mockModels[index],
                      onChangedBodyResponse: (value) async {
                        mockModel!.mockModels[index].responseBody = value;
                        await save();
                        setState(() {});
                      },
                      onChangedCheck: (value) async {
                        mockModel!.mockModels[index].enable = value ?? false;
                        await save();
                        setState(() {});
                      },
                      onChangedEndpoint: (value) async {
                        mockModel!.mockModels[index].endpoint = value;
                        await save();
                        setState(() {});
                      },
                      onChangedStatusCode: (value) async {
                        mockModel!.mockModels[index].statusCode = int.parse(
                          value,
                        );
                        await save();
                        setState(() {});
                      },
                      onChangedHeaderResponse: (value) async {
                        mockModel!
                            .mockModels[index]
                            .responseHeader = parseHeader(value);
                        await save();
                        setState(() {});
                      },
                      onChangedMethod: (value) async {
                        mockModel!.mockModels[index].method = value;
                        await save();
                        setState(() {});
                      },
                      onDelete: () async {
                        mockModel!.mockModels.removeAt(index);
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
                valueListenable: server.logService.logs,
                builder: (context, logs, _) {
                  return ListView.builder(
                    itemCount: logs.length,
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
                        (mockModel?.mockModels.where((e) => e.enable).length ??
                            0) !=
                        0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_tethering, size: 15),
                        SizedBox(width: 5),
                        Text(
                          '${mockModel?.mockModels.where((e) => e.enable).length} ${server.isRunning ? 'running...' : 'ready to mock'}',
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
      floatingActionButton: FloatingActionButton(
        backgroundColor:
            server.isRunning ? Colors.red : colors(context).greenDarkness,
        onPressed: () async {
          server.setHost = mockModel?.host ?? '';
          server.setPort = mockModel?.port ?? 8080;
          if (portController.text.isEmpty) {
            portController.text = server.port.toString();
          }

          server.clearRouters();

          if (server.isRunning) {
            await server.stop();
            setState(() {});
            return;
          }

          for (var mockModel in mockModel?.mockModels ?? <MockModel>[]) {
            if (!mockModel.enable) continue;
            // Tambah router baru
            final customRouter = getRouter(mockModel.method, mockModel);
            server.addRouter(customRouter);
          }

          setState(() {});
          await server.run();
          await save();
        },
        child: Icon(
          server.isRunning ? Icons.stop : Icons.play_arrow,
          color: Colors.white,
        ),
      ),
    );
  }

  shelf_router.Router getRouter(String method, MockModel mockModel) {
    switch (method) {
      case 'GET':
        return shelf_router.Router()..get(
          mockModel.endpoint,
          (shelf.Request request) => shelf.Response(
            mockModel.statusCode,
            headers: mockModel.responseHeader,
            body: mockModel.responseBody,
          ),
        );
      case 'POST':
        return shelf_router.Router()..post(
          mockModel.endpoint,
          (shelf.Request request) => shelf.Response(
            mockModel.statusCode,
            headers: mockModel.responseHeader,
            body: mockModel.responseBody,
          ),
        );
      case 'PUT':
        return shelf_router.Router()..put(
          mockModel.endpoint,
          (shelf.Request request) => shelf.Response(
            mockModel.statusCode,
            headers: mockModel.responseHeader,
            body: mockModel.responseBody,
          ),
        );
      case 'PATCH':
        return shelf_router.Router()..patch(
          mockModel.endpoint,
          (shelf.Request request) => shelf.Response(
            mockModel.statusCode,
            headers: mockModel.responseHeader,
            body: mockModel.responseBody,
          ),
        );
      case 'DELETE':
        return shelf_router.Router()..delete(
          mockModel.endpoint,
          (shelf.Request request) => shelf.Response(
            mockModel.statusCode,
            headers: mockModel.responseHeader,
            body: mockModel.responseBody,
          ),
        );
      default:
        return shelf_router.Router()..get(
          mockModel.endpoint,
          (shelf.Request request) => shelf.Response.ok('This is custom route'),
        );
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
