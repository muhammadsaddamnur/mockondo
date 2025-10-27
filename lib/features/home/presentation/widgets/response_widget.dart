import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/server.dart';
import 'package:mockondo/core/utils.dart';
import 'package:mockondo/core/widgets/custom_json_textfield.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:re_editor/re_editor.dart';

enum OffsetType {
  param,
  custom;

  bool isParam() {
    return this == OffsetType.param;
  }
}

class ResponseWidget extends StatefulWidget {
  const ResponseWidget({
    super.key,
    required this.server,
    required this.endpointIndex,
  });

  final MainServer server;
  final int endpointIndex;

  @override
  State<ResponseWidget> createState() => _ResponseWidgetState();
}

class _ResponseWidgetState extends State<ResponseWidget> {
  final homeController = Get.find<HomeController>();

  bool isPagination = false;
  bool enablePagination = false;

  final dataPaginationController = CodeLineEditingController();

  OffsetType selectedOffsetType = OffsetType.param;
  OffsetType selectedLimitType = OffsetType.param;

  final headerResponseController = CodeLineEditingController();
  final bodyResponseController = CodeLineEditingController();

  final offsetParamController = TextEditingController();
  final customOffsetController = TextEditingController();
  final customLimitController = TextEditingController();
  final limitParamController = TextEditingController();
  final maxController = TextEditingController();

  @override
  void dispose() {
    headerResponseController.dispose();
    bodyResponseController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    final mock =
        homeController
            .mockModels[homeController.selectedMockModelIndex.value]
            ?.mockModels[widget.endpointIndex];

    headerResponseController.text =
        mock?.responseHeader == null
            ? jsonEncode({'Content-Type': 'application/json'})
            : jsonEncode(mock?.responseHeader);
    bodyResponseController.text = (mock?.responseBody).toString();

    offsetParamController.text =
        mock?.rules
            ?.firstWhereOrNull((e) => e.type == RulesType.pagination)
            ?.rules['offset_param'] ??
        '';
    limitParamController.text =
        mock?.rules
            ?.firstWhereOrNull((e) => e.type == RulesType.pagination)
            ?.rules['limit_param'] ??
        '';
    maxController.text =
        (mock?.rules
                    ?.firstWhereOrNull((e) => e.type == RulesType.pagination)
                    ?.rules['max'] ??
                '')
            .toString();

    dataPaginationController.text =
        mock?.rules
            ?.firstWhereOrNull((e) => e.type == RulesType.pagination)
            ?.response ??
        '';

    ///comming soon
    // customOffsetController = TextEditingController();
    // customLimitController = TextEditingController();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width / 1.5,
      height: MediaQuery.sizeOf(context).height / 1.2,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: AlignmentGeometry.centerRight,
              child: InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  headerResponseController.clearHistory();
                  bodyResponseController.clearHistory();
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.close, size: 12),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      isPagination = false;
                    });
                  },
                  child: Container(
                    color:
                        !isPagination
                            ? AppColors.textD.withValues(alpha: 0.3)
                            : Colors.transparent,
                    height: 30,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Normal',
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
                SizedBox(width: 10),
                InkWell(
                  onTap: () {
                    setState(() {
                      isPagination = true;
                    });
                  },
                  child: Container(
                    color:
                        isPagination
                            ? AppColors.textD.withValues(alpha: 0.3)
                            : Colors.transparent,
                    height: 30,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Pagination',
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
              ],
            ),
            SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Response Header',
                              style: TextStyle(
                                color: AppColors.textD,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(height: 5),
                            CustomJsonTextField(
                              hintText: 'Response Header',
                              height: 150,
                              controller: headerResponseController,
                              // onChanged: widget.onChangedHeaderResponse,
                              onChanged: (c) {},
                              readOnly: widget.server.isRunning,
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Response Body',
                                style: TextStyle(
                                  color: AppColors.textD,
                                  fontSize: 12,
                                ),
                              ),
                              SizedBox(height: 5),
                              Expanded(
                                child: CustomJsonTextField(
                                  hintText: 'Response Body',
                                  controller: bodyResponseController,
                                  // onChanged: widget.onChangedBodyResponse,
                                  onChanged: (c) {},
                                  readOnly: widget.server.isRunning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isPagination) ...[
                    SizedBox(width: 10),
                    Container(
                      width: 1,
                      color: AppColors.textD.withValues(alpha: 0.3),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ListView(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pagination Settings',
                                      style: TextStyle(
                                        color: AppColors.textD,
                                        fontSize: 12,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Configure your pagination settings here.',
                                      style: TextStyle(
                                        color: AppColors.textD.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          // Add more pagination settings widgets here
                          SizedBox(height: 10),

                          /// offset
                          Row(
                            children: [
                              SizedBox(
                                height: 30,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    selectedOffsetType = OffsetType.param;
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    selectedOffsetType.isParam()
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color:
                                        selectedOffsetType.isParam()
                                            ? colors(context).greenDarkness
                                            : null,
                                  ),
                                ),
                              ),
                              SizedBox(width: 5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Query Param for page',
                                      style: TextStyle(
                                        color: AppColors.textD,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      "Example: if the client sends http://192.0.0.1:8081/mockondo?page=1&limit=10, then the input should be 'page'",
                                      style: TextStyle(
                                        color: AppColors.textD,
                                        fontSize: 10,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    SizedBox(
                                      height: 30,
                                      child: CustomTextField(
                                        controller: offsetParamController,
                                        hintText: 'Input here!',
                                        readOnly: widget.server.isRunning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Divider(),

                          /// comming soon
                          // Row(
                          //   children: [
                          //     SizedBox(
                          //       height: 30,
                          //       child: IconButton(
                          //         padding: EdgeInsets.zero,
                          //         onPressed: () {
                          //           selectedOffsetType = OffsetType.custom;
                          //           setState(() {});
                          //         },
                          //         icon: Icon(
                          //           !selectedOffsetType.isParam()
                          //               ? Icons.radio_button_checked_rounded
                          //               : Icons.radio_button_off_rounded,
                          //           color:
                          //               !selectedOffsetType.isParam()
                          //                   ? colors(context).greenDarkness
                          //                   : null,
                          //         ),
                          //       ),
                          //     ),
                          //     SizedBox(width: 5),
                          //     Expanded(
                          //       child: Column(
                          //         crossAxisAlignment: CrossAxisAlignment.start,
                          //         children: [
                          //           Text(
                          //             'Custom Offset',
                          //             style: TextStyle(
                          //               color: AppColors.textD,
                          //               fontSize: 12,
                          //             ),
                          //           ),
                          //           Text(
                          //             'Has a "page" parameter in the query params',
                          //             style: TextStyle(
                          //               color: AppColors.textD,
                          //               fontSize: 10,
                          //             ),
                          //           ),
                          //           SizedBox(height: 5),
                          //           SizedBox(
                          //             height: 30,
                          //             child: CustomTextField(
                          //               controller: customOffsetController,
                          //               hintText: 'Input offset of data',
                          //               keyboardType: TextInputType.number,
                          //               inputFormatters: [
                          //                 FilteringTextInputFormatter
                          //                     .digitsOnly,
                          //               ],
                          //               readOnly: widget.server.isRunning,
                          //             ),
                          //           ),
                          //         ],
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          SizedBox(height: 10),

                          /// limit
                          Row(
                            children: [
                              SizedBox(
                                height: 30,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: () {
                                    selectedLimitType = OffsetType.param;
                                    setState(() {});
                                  },
                                  icon: Icon(
                                    selectedLimitType.isParam()
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color:
                                        selectedLimitType.isParam()
                                            ? colors(context).greenDarkness
                                            : null,
                                  ),
                                ),
                              ),
                              SizedBox(width: 5),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Query Param for limit',
                                      style: TextStyle(
                                        color: AppColors.textD,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      "Example: if the client sends http://192.0.0.1:8081/mockondo?page=1&limit=10, then the input should be 'limit'",
                                      style: TextStyle(
                                        color: AppColors.textD,
                                        fontSize: 10,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    SizedBox(
                                      height: 30,
                                      child: CustomTextField(
                                        controller: limitParamController,
                                        hintText: 'Input here!',
                                        readOnly: widget.server.isRunning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Divider(),
                          // Row(
                          //   children: [
                          //     SizedBox(
                          //       height: 30,
                          //       child: IconButton(
                          //         padding: EdgeInsets.zero,
                          //         onPressed: () {
                          //           selectedLimitType = OffsetType.custom;
                          //           setState(() {});
                          //         },
                          //         icon: Icon(
                          //           !selectedLimitType.isParam()
                          //               ? Icons.radio_button_checked_rounded
                          //               : Icons.radio_button_off_rounded,
                          //           color:
                          //               !selectedLimitType.isParam()
                          //                   ? colors(context).greenDarkness
                          //                   : null,
                          //         ),
                          //       ),
                          //     ),
                          //     SizedBox(width: 5),
                          //     Expanded(
                          //       child: Column(
                          //         crossAxisAlignment: CrossAxisAlignment.start,
                          //         children: [
                          //           Text(
                          //             'Custom Limit',
                          //             style: TextStyle(
                          //               color: AppColors.textD,
                          //               fontSize: 12,
                          //             ),
                          //           ),
                          //           Text(
                          //             'Has a "page" parameter in the query params',
                          //             style: TextStyle(
                          //               color: AppColors.textD,
                          //               fontSize: 10,
                          //             ),
                          //           ),
                          //           SizedBox(height: 5),
                          //           SizedBox(
                          //             height: 30,
                          //             child: CustomTextField(
                          //               controller: customLimitController,
                          //               hintText: 'Input offset of data',
                          //               keyboardType: TextInputType.number,
                          //               inputFormatters: [
                          //                 FilteringTextInputFormatter
                          //                     .digitsOnly,
                          //               ],
                          //               readOnly: widget.server.isRunning,
                          //             ),
                          //           ),
                          //         ],
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          SizedBox(height: 10),

                          SizedBox(height: 10),
                          Text(
                            'Max Data',
                            style: TextStyle(
                              color: AppColors.textD,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 5),
                          SizedBox(
                            height: 30,
                            child: CustomTextField(
                              hintText: 'Input here!',
                              controller: maxController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              readOnly: widget.server.isRunning,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'The data to be returned in the pagination',
                            style: TextStyle(
                              color: AppColors.textD,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 5),
                          Expanded(
                            child: CustomJsonTextField(
                              hintText: 'Input here!',
                              controller: dataPaginationController,
                              onChanged: (data) {},
                              readOnly: widget.server.isRunning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // ElevatedButton(
                  //   onPressed: () {
                  //     log(dataPaginationController.text.removeAllWhitespace);
                  //   },
                  //   style: ButtonStyle(elevation: WidgetStatePropertyAll(0)),
                  //   child: Text('get'),
                  // ),
                  ElevatedButton(
                    onPressed: () {
                      homeController.setPagination(
                        widget.endpointIndex,
                        dataPaginationController.text.removeAllWhitespace
                            .trim(),
                        PaginationParams(
                          customLimit:
                              selectedLimitType.isParam()
                                  ? null
                                  : int.parse(
                                    customLimitController.text.trim(),
                                  ),
                          limitParam:
                              !selectedLimitType.isParam()
                                  ? null
                                  : limitParamController.text.trim(),
                          customOffset:
                              selectedOffsetType.isParam()
                                  ? null
                                  : int.parse(
                                    customOffsetController.text.trim(),
                                  ),
                          offsetParam:
                              !selectedOffsetType.isParam()
                                  ? null
                                  : offsetParamController.text.trim(),
                          max: int.tryParse(maxController.text.trim()) ?? 0,
                        ),
                      );

                      homeController.saveAllResponseConfig(
                        endpointIndex: widget.endpointIndex,
                        responseBody: bodyResponseController.text,
                        responseHeader: Utils.parseHeader(
                          headerResponseController.text,
                        ),
                      );

                      Navigator.pop(context);
                    },
                    style: ButtonStyle(elevation: WidgetStatePropertyAll(0)),
                    child: Text('Save'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
