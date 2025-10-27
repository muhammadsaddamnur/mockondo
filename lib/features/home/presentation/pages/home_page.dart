import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/log.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/routing_core.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/home/presentation/widgets/endpoint_widget.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final homeController = Get.put(HomeController());
  var reset = false;

  Future<void> change() async {
    reset = true;
    await Future.delayed(Duration(milliseconds: 10));
    reset = false;
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
              child: Obx(() {
                return ListView(
                  children: [
                    ...List.generate(
                      homeController.mockModels.length,
                      (index) => InkWell(
                        onTap: () {
                          final mock =
                              homeController.mockModels[homeController
                                  .selectedMockModelIndex
                                  .value];
                          homeController.selectedMockModelIndex.value = index;
                          homeController.hostController.text = mock?.host ?? '';
                          homeController.portController.text =
                              (mock?.port ?? 8080).toString();
                          change();
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
                                        text:
                                            homeController
                                                .mockModels[index]
                                                ?.name ??
                                            '',
                                      ),
                                      hintText: 'Project Name',
                                      onChanged: (value) {
                                        homeController.mockModels[index]?.name =
                                            value;
                                        setState(() {});
                                      },
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      homeController.removeModel(index);
                                      Navigator.of(context).pop();
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
                              homeController.selectedMockModelIndex.value ==
                                      index
                                  ? AppColors.textD.withValues(alpha: 0.3)
                                  : Colors.transparent,
                          height: 50,
                          child: Center(
                            child: Text(
                              homeController.mockModels[index]?.name ??
                                  'Unnamed Project',
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
                          homeController.createModel();
                        },
                        child: Text('Add Project'),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          Obx(() {
            final serverIsRunning = homeController.serverIsRunning();

            if (homeController.mockModels.isEmpty) {
              return Expanded(
                child: Center(
                  child: Text(
                    'No project available. Please add a new project.',
                    style: TextStyle(color: AppColors.textD, fontSize: 16),
                  ),
                ),
              );
            } else {
              return Expanded(
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
                                    controller: homeController.hostController,
                                    hintText:
                                        'Proxy Target URL : https://example.com',
                                    readOnly: serverIsRunning,
                                    onChanged: (value) async {
                                      homeController
                                          .mockModels[homeController
                                              .selectedMockModelIndex
                                              .value]!
                                          .host = value;
                                      await homeController.save();
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ),
                            ),
                            Icon(Icons.keyboard_arrow_right_rounded),
                            Expanded(
                              child: Tooltip(
                                message:
                                    'On the Android emulator, it usually starts with 10.0.0.2, or you can check it in the emulator settings.',
                                child: SizedBox(
                                  height: 30,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SelectableText(
                                          '${homeController.ipAddress.value}${!serverIsRunning ? '' : ':${homeController.mockModels[homeController.selectedMockModelIndex.value]?.server?.port}'}',
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
                            ),
                            SizedBox(width: 5),
                            SizedBox(
                              height: 30,
                              width: 100,
                              child: Center(
                                child: CustomTextField(
                                  controller: homeController.portController,
                                  hintText: 'Port',
                                  readOnly: serverIsRunning,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  onChanged: (value) async {
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]!
                                        .port = int.parse(
                                      value.isEmpty ? '8080' : value,
                                    );
                                    await homeController.save();
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
                                serverIsRunning
                                    ? null
                                    : () async {
                                      var m =
                                          homeController
                                              .mockModels[homeController
                                                  .selectedMockModelIndex
                                                  .value]
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
                                      homeController.mockModels[homeController
                                          .selectedMockModelIndex
                                          .value] = homeController
                                          .mockModels[homeController
                                              .selectedMockModelIndex
                                              .value]
                                          ?.copyWith(mockModels: m);
                                      await homeController.save();
                                      setState(() {});
                                    },
                            child: Text('Add Endpoint'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Obx(() {
                          if (reset) return SizedBox();

                          return ListView.builder(
                            itemCount:
                                homeController
                                    .mockModels[homeController
                                        .selectedMockModelIndex
                                        .value]
                                    ?.mockModels
                                    .length ??
                                0,
                            itemBuilder: (context, index) {
                              /// Get current mock model
                              final current =
                                  homeController
                                      .mockModels[homeController
                                          .selectedMockModelIndex
                                          .value]!
                                      .mockModels[index];

                              /// check if there is prior same enabled endpoint with same method
                              final hasPriorSame = homeController
                                  .mockModels[homeController
                                      .selectedMockModelIndex
                                      .value]!
                                  .mockModels
                                  .sublist(0, index)
                                  .any(
                                    (e) =>
                                        e.enable &&
                                        e.endpoint == current.endpoint &&
                                        e.method == current.method,
                                  );

                              /// determine if this is not the first running endpoint with same method and endpoint
                              final isNotFirstRunning =
                                  serverIsRunning && hasPriorSame;

                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: EndpointWidget(
                                  endpointIndex: index,
                                  isNotFirstRunning: isNotFirstRunning,
                                  onChangedCheck: (value) async {
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]!
                                        .mockModels[index]
                                        .enable = value ?? false;
                                    await homeController.save();
                                    setState(() {});
                                  },
                                  onChangedEndpoint: (value) async {
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]!
                                        .mockModels[index]
                                        .endpoint = value;
                                    await homeController.save();
                                    setState(() {});
                                  },
                                  onChangedStatusCode: (value) async {
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]!
                                        .mockModels[index]
                                        .statusCode = int.parse(value);
                                    await homeController.save();
                                    setState(() {});
                                  },
                                  onChangedDelay: (value) async {
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]!
                                        .mockModels[index]
                                        .delay = int.parse(value);
                                    await homeController.save();
                                    setState(() {});
                                  },
                                  onChangedMethod: (value) async {
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]!
                                        .mockModels[index]
                                        .method = value;
                                    await homeController.save();
                                    setState(() {});
                                  },
                                  onDelete: () async {
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]!
                                        .mockModels
                                        .removeAt(index);
                                    await homeController.save();
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                          );
                        }),
                      ),
                    ),
                    Visibility(
                      visible: homeController.showLog.value,
                      child: Container(
                        height: 200,
                        width: MediaQuery.sizeOf(context).width,
                        color: AppColors.terminalD,
                        child: ValueListenableBuilder<List<LogModel>>(
                          valueListenable:
                              homeController
                                  .mockModels[homeController
                                      .selectedMockModelIndex
                                      .value]
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
                                homeController.showLog.value =
                                    !homeController.showLog.value;
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
                                  (homeController
                                          .mockModels[homeController
                                              .selectedMockModelIndex
                                              .value]
                                          ?.mockModels
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
                                    '${homeController.mockModels[homeController.selectedMockModelIndex.value]?.mockModels.where((e) => e.enable).length} ${serverIsRunning ? 'running...' : 'ready to mock'}',
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
              );
            }
          }),
          // Column(
          //   children: [
          //     ElevatedButton(
          //       onPressed: () {
          //         homeController.clearAll();
          //       },
          //       child: Text('Clear All'),
          //     ),
          //     ElevatedButton(
          //       onPressed: () {
          //         homeController.getAll();
          //       },
          //       child: Text('Get All'),
          //     ),
          //   ],
          // ),
        ],
      ),
      floatingActionButton: Obx(() {
        return homeController.mockModels.isEmpty
            ? SizedBox()
            : FloatingActionButton(
              backgroundColor:
                  homeController.serverIsRunning()
                      ? Colors.red
                      : colors(context).greenDarkness,
              onPressed: () async {
                homeController
                    .mockModels[homeController.selectedMockModelIndex.value]
                    ?.server
                    ?.setHost = homeController
                        .mockModels[homeController.selectedMockModelIndex.value]
                        ?.host ??
                    '';
                homeController
                    .mockModels[homeController.selectedMockModelIndex.value]
                    ?.server
                    ?.setPort = homeController
                        .mockModels[homeController.selectedMockModelIndex.value]
                        ?.port ??
                    8080;
                if (homeController.portController.text.isEmpty) {
                  homeController.portController.text =
                      homeController
                          .mockModels[homeController
                              .selectedMockModelIndex
                              .value]!
                          .server!
                          .port
                          .toString();
                }

                homeController
                    .mockModels[homeController.selectedMockModelIndex.value]
                    ?.server
                    ?.clearRouters();

                if (homeController.serverIsRunning()) {
                  await homeController
                      .mockModels[homeController.selectedMockModelIndex.value]
                      ?.server
                      ?.stop();
                  setState(() {});
                  return;
                }

                for (var mockModel
                    in homeController
                            .mockModels[homeController
                                .selectedMockModelIndex
                                .value]
                            ?.mockModels ??
                        <MockModel>[]) {
                  if (!mockModel.enable) continue;
                  // Tambah router baru
                  final customRouter = RoutingCore.getRouter(
                    mockModel.method,
                    mockModel,
                  );
                  homeController
                      .mockModels[homeController.selectedMockModelIndex.value]
                      ?.server
                      ?.addRouter(customRouter);
                }

                setState(() {});
                await homeController
                    .mockModels[homeController.selectedMockModelIndex.value]
                    ?.server
                    ?.run();
                await homeController.save();
              },
              child: Icon(
                homeController.serverIsRunning()
                    ? Icons.stop
                    : Icons.play_arrow,
                color: Colors.white,
              ),
            );
      }),
    );
  }
}
