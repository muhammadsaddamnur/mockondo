import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/routing_core.dart';
import 'package:mockondo/core/schema_service.dart';
import 'package:mockondo/core/widgets/button_widget.dart';
import 'package:mockondo/core/widgets/chip_start.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/custom_data/pages/custom_data_page.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/home/presentation/widgets/endpoint_widget.dart';
import 'package:mockondo/features/home/presentation/widgets/terminal_widget.dart';
import 'package:mockondo/features/home/presentation/widgets/ws_endpoint_widget.dart';
import 'package:mockondo/features/http_client/presentation/pages/http_client_page.dart';
import 'package:mockondo/features/json_to_code/presentation/pages/json_to_code_page.dart';
import 'package:mockondo/features/mock_s3/presentation/pages/mock_s3_page.dart';
import 'package:mockondo/features/settings/presentation/pages/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

enum _AppMode { mock, httpClient, jsonToCode, mockS3, customData, logs, settings }

class _HomePageState extends State<HomePage> {
  final homeController = Get.put(HomeController());
  var reset = false;
  _AppMode _mode = _AppMode.mock;
  // 0 = HTTP endpoints, 1 = WebSocket endpoints
  int _endpointTab = 0;

  Future<void> change() async {
    reset = true;
    await Future.delayed(Duration(milliseconds: 10));
    reset = false;
    setState(() {});
  }

  void _showProjectMenu(BuildContext context, int index, Offset position) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      color: AppColors.backgroundD,
      items: [
        PopupMenuItem(
          onTap: () {
            final ctrl = TextEditingController(
              text: homeController.mockModels[index]?.name ?? '',
            );
            Future.delayed(Duration.zero, () {
              if (!mounted) return;
              showDialog(
                context: context,
                builder:
                    (_) => AlertDialog(
                      backgroundColor: colors(context).backgroundDarkness,
                      title: Text(
                        'Rename Project',
                        style: TextStyle(
                          color: AppColors.textD,
                          fontSize: AppTextSize.title,
                        ),
                      ),
                      content: CustomTextField(
                        controller: ctrl,
                        hintText: 'Project Name',
                        onChanged: (v) {
                          homeController.mockModels[index]?.name = v;
                          setState(() {});
                        },
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(color: AppColors.textD),
                          ),
                        ),
                      ],
                    ),
              );
            });
          },
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 13, color: AppColors.textD),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Rename',
                style: TextStyle(
                  color: AppColors.textD,
                  fontSize: AppTextSize.body,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            final project = homeController.mockModels[index];
            if (project == null) return;
            SchemaService.exportOpenApi(context, project);
          },
          child: Row(
            children: [
              Icon(Icons.upload_outlined, size: 13, color: AppColors.textD),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Export OpenAPI (HTTP)',
                style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            SchemaService.importOpenApi(context).then((endpoints) {
              if (!mounted || endpoints == null || endpoints.isEmpty) return;
              final project = homeController.mockModels[index];
              if (project == null) return;
              project.mockModels.addAll(endpoints);
              homeController.mockModels[index] = project;
              homeController.save();
              setState(() {});
            });
          },
          child: Row(
            children: [
              Icon(Icons.download_outlined, size: 13, color: AppColors.textD),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Import OpenAPI (HTTP)',
                style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            final project = homeController.mockModels[index];
            if (project == null) return;
            SchemaService.exportAsyncApi(context, project);
          },
          child: Row(
            children: [
              Icon(Icons.upload_outlined, size: 13, color: const Color(0xFF4DFFD6)),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Export AsyncAPI (WS)',
                style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            SchemaService.importAsyncApi(context).then((wsModels) {
              if (!mounted || wsModels == null || wsModels.isEmpty) return;
              final project = homeController.mockModels[index];
              if (project == null) return;
              project.wsMockModels.addAll(wsModels);
              homeController.mockModels[index] = project;
              homeController.save();
              setState(() {});
            });
          },
          child: Row(
            children: [
              Icon(Icons.download_outlined, size: 13, color: const Color(0xFF4DFFD6)),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Import AsyncAPI (WS)',
                style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            homeController.removeModel(index);
            setState(() {});
          },
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 13, color: AppColors.red),
              const SizedBox(width: AppSpacing.m),
              Text(
                'Delete',
                style: TextStyle(
                  color: AppColors.red,
                  fontSize: AppTextSize.body,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors(context).backgroundDarkness,
      body: Row(
        children: [
          // ── Activity bar ──────────────────────────────────────────
          Container(
            width: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceD.withValues(alpha: 0.2),
              border: Border(
                right: BorderSide(
                  color: AppColors.textD.withValues(alpha: 0.1),
                ),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.m),
                _ActivityIcon(
                  icon: Icons.dns_outlined,
                  label: 'Mock Server',
                  selected: _mode == _AppMode.mock,
                  onTap: () => setState(() => _mode = _AppMode.mock),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActivityIcon(
                  icon: Icons.drive_folder_upload_outlined,
                  label: 'Mock Storage',
                  selected: _mode == _AppMode.mockS3,
                  onTap: () => setState(() => _mode = _AppMode.mockS3),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActivityIcon(
                  icon: Icons.send_outlined,
                  label: 'HTTP/WS Client',
                  selected: _mode == _AppMode.httpClient,
                  onTap: () => setState(() => _mode = _AppMode.httpClient),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActivityIcon(
                  icon: Icons.code,
                  label: 'JSON to Code',
                  selected: _mode == _AppMode.jsonToCode,
                  onTap: () => setState(() => _mode = _AppMode.jsonToCode),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActivityIcon(
                  icon: Icons.data_object,
                  label: 'Custom Data',
                  selected: _mode == _AppMode.customData,
                  onTap: () => setState(() => _mode = _AppMode.customData),
                ),
                const Spacer(),
                _ActivityIcon(
                  icon: Icons.terminal_rounded,
                  label: 'Logs',
                  selected: _mode == _AppMode.logs,
                  onTap: () => setState(() => _mode = _AppMode.logs),
                ),
                const SizedBox(height: AppSpacing.xs),
                _ActivityIcon(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  selected: _mode == _AppMode.settings,
                  onTap: () => setState(() => _mode = _AppMode.settings),
                ),
                const SizedBox(height: AppSpacing.m),
              ],
            ),
          ),

          // ── Page content switches based on mode ───────────────────
          if (_mode == _AppMode.settings) ...[
            const Expanded(child: SettingsPage()),
          ] else if (_mode == _AppMode.httpClient) ...[
            Expanded(child: HttpClientPage()),
          ] else if (_mode == _AppMode.jsonToCode) ...[
            const Expanded(child: JsonToCodePage()),
          ] else if (_mode == _AppMode.mockS3) ...[
            const Expanded(child: MockS3Page()),
          ] else if (_mode == _AppMode.customData) ...[
            Expanded(child: CustomDataPage()),
          ] else if (_mode == _AppMode.logs) ...[
            Expanded(
              child: Obx(() {
                final mockModels = homeController.mockModels;
                final selectedIndex = homeController.selectedMockModelIndex.value;

                if (mockModels.isEmpty) {
                  return Center(
                    child: Text(
                      'No projects available',
                      style: TextStyle(
                        color: AppColors.textD.withValues(alpha: 0.5),
                        fontSize: AppTextSize.body,
                      ),
                    ),
                  );
                }

                final selectedMock = mockModels[selectedIndex];
                final logNotifier = selectedMock?.server?.logService.logs;

                if (logNotifier == null) {
                  return Center(
                    child: Text(
                      'No logs available',
                      style: TextStyle(
                        color: AppColors.textD.withValues(alpha: 0.5),
                        fontSize: AppTextSize.body,
                      ),
                    ),
                  );
                }

                return TerminalWidget(logNotifier: logNotifier);
              }),
            ),
          ] else ...[
            // ── Mock sidebar ─────────────────────────────────────────
            Container(
              width: 200,
              decoration: BoxDecoration(
                color: AppColors.backgroundD,
                border: Border(
                  right: BorderSide(
                    color: AppColors.textD.withValues(alpha: 0.1),
                  ),
                ),
              ),
              child: Obx(() {
                return Column(
                  children: [
                    // Header
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.m,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.textD.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.dns_outlined, size: 14, color: AppColors.secondaryD),
                          const SizedBox(width: AppSpacing.s),
                          Text(
                            'Mock Server',
                            style: TextStyle(
                              color: AppColors.textD,
                              fontSize: AppTextSize.title,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Tooltip(
                            message: 'MOCK Server',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(4),
                              onTap: homeController.createModel,
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                child: Icon(
                                  Icons.add,
                                  size: 16,
                                  color: AppColors.greenD,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: AppColors.textD.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Project list
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        itemCount: homeController.mockModels.length,
                        itemBuilder: (context, index) {
                          final mock = homeController.mockModels[index];
                          final isSelected =
                              homeController.selectedMockModelIndex.value ==
                              index;
                          final isRunning = mock?.server?.isRunning ?? false;
                          return GestureDetector(
                            onSecondaryTapDown:
                                (d) => _showProjectMenu(
                                  context,
                                  index,
                                  d.globalPosition,
                                ),
                            child: InkWell(
                              onTap: () {
                                homeController.changeProject(index);
                                change();
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                height: 52,
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.xs,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.m,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  color:
                                      isSelected
                                          ? AppColors.secondaryD.withValues(
                                            alpha: 0.18,
                                          )
                                          : Colors.transparent,
                                  border:
                                      isSelected
                                          ? Border.all(
                                            color: AppColors.secondaryD
                                                .withValues(alpha: 0.3),
                                          )
                                          : null,
                                ),
                                child: Row(
                                  children: [
                                    // Running indicator dot
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.only(
                                        right: AppSpacing.s,
                                      ),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color:
                                            isRunning
                                                ? AppColors.greenD
                                                : AppColors.textD.withValues(
                                                  alpha: 0.25,
                                                ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mock?.name ?? 'Unnamed',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppColors.textD,
                                              fontSize: AppTextSize.body,
                                              fontWeight:
                                                  isSelected
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                            ),
                                          ),
                                          Text(
                                            ':${mock?.port ?? 8080}',
                                            style: TextStyle(
                                              color: AppColors.textD.withValues(
                                                alpha: 0.45,
                                              ),
                                              fontSize: AppTextSize.badge,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // // Add project button
                    // Padding(
                    //   padding: const EdgeInsets.all(AppSpacing.m),
                    //   child: SizedBox(
                    //     width: double.infinity,
                    //     child: ElevatedButton.icon(
                    //       onPressed: homeController.createModel,
                    //       style: ElevatedButton.styleFrom(elevation: 0),
                    //       icon: const Icon(Icons.add, size: 14),
                    //       label: const Text(
                    //         'Add Project',
                    //         style: TextStyle(fontSize: AppTextSize.body),
                    //       ),
                    //     ),
                    //   ),
                    // ),
                  ],
                );
              }),
            ),
            Obx(() {
              final serverIsRunning = homeController.serverIsRunning();

              if (homeController.mockModels.isEmpty) {
                return Expanded(
                  child: Center(
                    child: Text(
                      'No project available. Please add a new project.',
                      style: TextStyle(
                        color: AppColors.textD,
                        fontSize: AppTextSize.title,
                      ),
                    ),
                  ),
                );
              } else {
                return Expanded(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.m),
                        child: SizedBox(
                          height: 50,
                          child: Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 30,
                                  child: Center(
                                    child: Obx(() {
                                      return CustomTextField(
                                        controller:
                                            homeController.hostController.value,
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
                                      );
                                    }),
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
                                          Obx(() {
                                            return SelectableText(
                                              '${homeController.ipAddress.value}${!serverIsRunning ? '' : ':${homeController.mockModels[homeController.selectedMockModelIndex.value]?.server?.port}'}',
                                              style: TextStyle(
                                                color: AppColors.textD,
                                                fontSize: AppTextSize.title,
                                              ),
                                            );
                                          }),
                                          Text(
                                            'your ip address',
                                            style: TextStyle(
                                              color: AppColors.textD,
                                              fontSize: AppTextSize.badge,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // child: Center(child: CustomTextField()),
                                  ),
                                ),
                              ),
                              SizedBox(width: AppSpacing.s),
                              SizedBox(
                                height: 30,
                                width: 100,
                                child: Center(
                                  child: Obx(() {
                                    return CustomTextField(
                                      controller:
                                          homeController.portController.value,
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
                                    );
                                  }),
                                ),
                              ),
                              SizedBox(width: AppSpacing.s),
                              Obx(
                                () => ChipStart(
                                  label:
                                      homeController.serverIsRunning()
                                          ? 'Stop'
                                          : 'Start',
                                  color:
                                      homeController.serverIsRunning()
                                          ? AppColors.red
                                          : AppColors.greenD,
                                  onTap: () async {
                                    homeController.getIpAddress();
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]
                                        ?.server
                                        ?.setHost = homeController
                                            .mockModels[homeController
                                                .selectedMockModelIndex
                                                .value]
                                            ?.host ??
                                        '';
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]
                                        ?.server
                                        ?.setPort = homeController
                                            .mockModels[homeController
                                                .selectedMockModelIndex
                                                .value]
                                            ?.port ??
                                        8080;
                                    if (homeController
                                        .portController
                                        .value
                                        .text
                                        .isEmpty) {
                                      homeController.portController.value.text =
                                          homeController
                                              .mockModels[homeController
                                                  .selectedMockModelIndex
                                                  .value]!
                                              .server!
                                              .port
                                              .toString();
                                    }

                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]
                                        ?.server
                                        ?.clearRouters();

                                    if (homeController.serverIsRunning()) {
                                      await homeController
                                          .mockModels[homeController
                                              .selectedMockModelIndex
                                              .value]
                                          ?.server
                                          ?.stop();
                                      setState(() {});
                                      return;
                                    }

                                    final project =
                                        homeController.mockModels[homeController
                                            .selectedMockModelIndex
                                            .value];

                                    // Register HTTP mock endpoints.
                                    for (final mockModel
                                        in project?.mockModels ??
                                            <MockModel>[]) {
                                      if (!mockModel.enable) continue;
                                      final customRouter = RoutingCore()
                                          .getRouter(
                                            mockModel.method,
                                            mockModel,
                                          );
                                      project?.server?.addRouter(customRouter);
                                    }

                                    // Register WebSocket mock endpoints.
                                    project?.server?.clearWsEndpoints();
                                    for (final wsModel
                                        in project?.wsMockModels ??
                                            <WsMockModel>[]) {
                                      if (!wsModel.enable) continue;
                                      project?.server?.addWsEndpoint(wsModel);
                                    }

                                    setState(() {});
                                    await homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]
                                        ?.server
                                        ?.run();
                                    await homeController.save();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Divider(thickness: 1),
                      // ── HTTP / WebSocket tab selector ─────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                          vertical: AppSpacing.s,
                        ),
                        child: Row(
                          children: [
                            _TabChip(
                              label: 'HTTP',
                              selected: _endpointTab == 0,
                              onTap: () => setState(() => _endpointTab = 0),
                            ),
                            const SizedBox(width: AppSpacing.s),
                            _TabChip(
                              label: 'WebSocket',
                              selected: _endpointTab == 1,
                              onTap: () => setState(() => _endpointTab = 1),
                              wsStyle: true,
                            ),
                            const Spacer(),
                            ButtonWidget(
                              color:
                                  _endpointTab == 0
                                      ? AppColors.secondaryD
                                      : AppColors.greenD,
                              onTap:
                                  serverIsRunning
                                      ? () async {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'Stop the server first to make changes',
                                                style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.body),
                                              ),
                                              duration: const Duration(seconds: 2),
                                              backgroundColor: AppColors.backgroundD,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      : () async {
                                        if (_endpointTab == 0) {
                                          final m =
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
                                          homeController
                                              .mockModels[homeController
                                              .selectedMockModelIndex
                                              .value] = homeController
                                              .mockModels[homeController
                                                  .selectedMockModelIndex
                                                  .value]
                                              ?.copyWith(mockModels: m);
                                          await homeController.save();
                                        } else {
                                          homeController.addWsEndpoint();
                                        }
                                        setState(() {});
                                      },
                              child: Text(
                                _endpointTab == 0
                                    ? 'Add Endpoint'
                                    : 'Add WS Endpoint',
                                style: TextStyle(fontSize: AppTextSize.body),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.m,
                            0,
                            AppSpacing.m,
                            AppSpacing.m,
                          ),
                          child: Obx(() {
                            if (reset) return const SizedBox();

                            if (_endpointTab == 1) {
                              // ── WebSocket endpoint list ───────────────────────
                              final wsList =
                                  homeController
                                      .mockModels[homeController
                                          .selectedMockModelIndex
                                          .value]
                                      ?.wsMockModels ??
                                  [];
                              if (wsList.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No WebSocket endpoints. Add one to get started.',
                                    style: TextStyle(
                                      color: AppColors.textD.withValues(
                                        alpha: 0.3,
                                      ),
                                      fontSize: AppTextSize.small,
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                itemCount: wsList.length,
                                itemBuilder:
                                    (context, index) => Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: WsEndpointWidget(
                                        wsIndex: index,
                                        onDelete: () async {
                                          homeController.removeWsEndpoint(
                                            index,
                                          );
                                          await change();
                                        },
                                      ),
                                    ),
                              );
                            }

                            // ── HTTP endpoint list ────────────────────────────
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
                                final current =
                                    homeController
                                        .mockModels[homeController
                                            .selectedMockModelIndex
                                            .value]!
                                        .mockModels[index];

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
                                          .delay = int.tryParse(value);
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
                      Container(
                        height: 25,
                        width: MediaQuery.sizeOf(context).width,
                        color: colors(
                          context,
                        ).secondaryDarkness.withValues(alpha: 0.2),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Visibility(
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
                                SizedBox(width: AppSpacing.s),
                                Text(
                                  '${homeController.mockModels[homeController.selectedMockModelIndex.value]?.mockModels.where((e) => e.enable).length} ${serverIsRunning ? 'running...' : 'ready to mock'}',
                                  style: TextStyle(
                                    fontSize: AppTextSize.body,
                                  ),
                                ),
                              ],
                            ),
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
          ], // close else branch
        ],
      ),
    );
  }
}

class _ActivityIcon extends StatelessWidget {
  const _ActivityIcon({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      preferBelow: false,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color:
                selected
                    ? AppColors.secondaryD.withValues(alpha: 0.25)
                    : Colors.transparent,
            border:
                selected
                    ? Border(
                      left: BorderSide(color: AppColors.secondaryD, width: 2),
                    )
                    : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color:
                selected
                    ? AppColors.secondaryD
                    : AppColors.textD.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

// ── Tab chip for HTTP / WebSocket switcher ────────────────────────────────────

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    this.onTap,
    this.wsStyle = false,
    this.bgColor,
  });

  final String label;
  final bool selected;
  final Function? onTap;
  final bool wsStyle;
  final Color? bgColor;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        wsStyle ? const Color(0xFF4DFFD6) : AppColors.secondaryD;
    return InkWell(
      onTap: onTap != null ? () => onTap!() : null,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
        decoration: BoxDecoration(
          color:
              bgColor ??
              (selected
                  ? activeColor.withValues(alpha: 0.12)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color:
                selected
                    ? activeColor.withValues(alpha: 0.5)
                    : AppColors.textD.withValues(alpha: 0.15),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? activeColor : AppColors.textD.withValues(alpha: 0.5),
            fontSize: AppTextSize.small,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
