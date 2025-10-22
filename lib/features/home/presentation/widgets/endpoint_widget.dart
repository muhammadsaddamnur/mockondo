import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/server.dart';
import 'package:mockondo/core/widgets/custom_json_textfield.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:re_editor/re_editor.dart';

class EndpointWidget extends StatefulWidget {
  final MockModel mockModel;
  final MainServer server;
  final void Function(bool?)? onChangedCheck;
  final void Function(String)? onChangedEndpoint;
  final void Function(String)? onChangedStatusCode;
  final void Function(String)? onChangedHeaderResponse;
  final void Function(String)? onChangedBodyResponse;
  final void Function(String)? onChangedMethod;
  final void Function(String)? onChangedDelay;
  final void Function()? onDelete;
  final bool isNotFirstRunning;

  const EndpointWidget({
    super.key,
    required this.server,
    required this.mockModel,
    required this.onChangedCheck,
    required this.onChangedEndpoint,
    required this.onChangedStatusCode,
    required this.onChangedHeaderResponse,
    required this.onChangedBodyResponse,
    required this.onChangedMethod,
    required this.onChangedDelay,
    required this.onDelete,
    this.isNotFirstRunning = false,
  });

  @override
  State<EndpointWidget> createState() => _EndpointWidgetState();
}

class _EndpointWidgetState extends State<EndpointWidget> {
  TextEditingController endpointController = TextEditingController();
  TextEditingController statusCodeController = TextEditingController();
  TextEditingController delayCodeController = TextEditingController();
  CodeLineEditingController headerResponseController =
      CodeLineEditingController();
  CodeLineEditingController bodyResponseController =
      CodeLineEditingController();
  bool showResponse = false;

  @override
  void initState() {
    endpointController.text = widget.mockModel.endpoint;
    statusCodeController.text = widget.mockModel.statusCode.toString();
    if (widget.mockModel.delay != null) {
      delayCodeController.text = widget.mockModel.delay.toString();
    }
    headerResponseController.text =
        widget.mockModel.responseHeader == null
            ? ''
            : jsonEncode(widget.mockModel.responseHeader);
    bodyResponseController.text = widget.mockModel.responseBody.toString();
    super.initState();
  }

  List<String> methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

  Color getColorMethod(String value) {
    switch (value) {
      case 'GET':
        return colors(context).greenDarkness;
      case 'POST':
        return Colors.blue;
      case 'PUT':
        return Colors.orange;
      case 'PATCH':
        return Colors.purpleAccent;
      case 'DELETE':
        return Colors.red;
      default:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.server.isRunning && widget.isNotFirstRunning) ...[
              SizedBox(width: 5),
              SizedBox(
                height: 30,
                child: Tooltip(
                  message:
                      'This endpoint has the same address as another endpoint currently running on this server. This endpoint will be ignored while the server is running.',
                  child: Icon(
                    Icons.info_outline,
                    color: colors(context).redDarkness,
                    size: 30,
                  ),
                ),
              ),
              SizedBox(width: 5),
            ],
            if (!widget.isNotFirstRunning) ...[
              SizedBox(
                height: 30,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed:
                      widget.server.isRunning
                          ? null
                          : () {
                            widget.onChangedCheck!(!widget.mockModel.enable);
                          },
                  icon: Icon(
                    widget.mockModel.enable
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color:
                        widget.mockModel.enable
                            ? colors(context).greenDarkness
                            : null,
                  ),
                ),
              ),
            ],
            SizedBox(
              width: 200,
              height: 30,
              child: CustomTextField(
                hintText: '/example',
                controller: endpointController,
                onChanged: widget.onChangedEndpoint,
                readOnly: widget.server.isRunning,
              ),
            ),
            SizedBox(width: 5),
            SizedBox(
              width: 100,
              height: 30,
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () {
                  if (widget.server.isRunning) return;
                  showDialog(
                    context: context,
                    builder:
                        (_) => Dialog(
                          child: SizedBox(
                            width: 100,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                methods.length,
                                (index) => ListTile(
                                  title: Text(
                                    methods[index],
                                    style: TextStyle(
                                      color: getColorMethod(methods[index]),
                                    ),
                                  ),
                                  onTap: () {
                                    widget.onChangedMethod!(methods[index]);
                                    Navigator.pop(context);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                  );
                },
                child: Center(
                  child: Text(
                    widget.mockModel.method,
                    style: TextStyle(
                      color: getColorMethod(widget.mockModel.method),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 5),
            SizedBox(
              width: 100,
              height: 30,
              child: CustomTextField(
                hintText: '200',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: statusCodeController,
                onChanged: widget.onChangedStatusCode,
                readOnly: widget.server.isRunning,
              ),
            ),
            SizedBox(width: 5),
            SizedBox(
              width: 100,
              height: 30,
              child: CustomTextField(
                hintText: 'Delay(ms)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: delayCodeController,
                onChanged: widget.onChangedDelay,
                readOnly: widget.server.isRunning,
              ),
            ),
            SizedBox(width: 20),
            SizedBox(
              width: 100,
              height: 30,
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () {
                  // showResponse = !showResponse;
                  showResponseDialog();
                  setState(() {});
                },
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Response',
                        style: TextStyle(color: AppColors.textD),
                      ),
                      Icon(
                        showResponse
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textD,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 5),
            SizedBox(
              height: 30,
              child: IconButton(
                padding: EdgeInsets.zero,
                onPressed:
                    widget.server.isRunning
                        ? null
                        : () {
                          widget.onDelete!();
                        },
                icon: Icon(Icons.delete, size: 15, color: AppColors.textD),
              ),
            ),
          ],
        ),
        // SizedBox(height: 5),
      ],
    );
  }

  void showResponseDialog() {
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            child: SizedBox(
              width: MediaQuery.sizeOf(context).width / 1.5,
              height: MediaQuery.sizeOf(context).height / 1.5,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
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
                                onChanged: widget.onChangedHeaderResponse,
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
                                    onChanged: widget.onChangedBodyResponse,
                                    readOnly: widget.server.isRunning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}
