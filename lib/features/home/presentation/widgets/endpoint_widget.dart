import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json_field_editor/json_field_editor.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/server.dart';
import 'package:mockondo/core/widgets/custom_json_textfield.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';

class EndpointWidget extends StatefulWidget {
  final MockModel mockModel;
  final MainServer server;
  final void Function(bool?)? onChangedCheck;
  final void Function(String)? onChangedEndpoint;
  final void Function(String)? onChangedStatusCode;
  final void Function(String)? onChangedHeaderResponse;
  final void Function(String)? onChangedBodyResponse;
  final void Function(String)? onChangedMethod;
  final void Function()? onDelete;

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
    required this.onDelete,
  });

  @override
  State<EndpointWidget> createState() => _EndpointWidgetState();
}

class _EndpointWidgetState extends State<EndpointWidget> {
  TextEditingController endpointController = TextEditingController();
  TextEditingController statusCodeController = TextEditingController();
  JsonTextFieldController headerResponseController = JsonTextFieldController();
  JsonTextFieldController bodyResponseController = JsonTextFieldController();

  @override
  void initState() {
    endpointController.text = widget.mockModel.endpoint;
    statusCodeController.text = widget.mockModel.statusCode.toString();
    headerResponseController.text =
        widget.mockModel.responseHeader == null
            ? ''
            : widget.mockModel.responseHeader.toString();
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Expanded(
          flex: 1,
          child: CustomJsonTextField(
            hintText: 'Response Header',
            controller: headerResponseController,
            onChanged: widget.onChangedHeaderResponse,
            readOnly: widget.server.isRunning,
          ),
        ),
        SizedBox(width: 5),
        Expanded(
          flex: 1,
          child: CustomJsonTextField(
            hintText: 'Response Body',
            controller: bodyResponseController,
            onChanged: widget.onChangedBodyResponse,
            readOnly: widget.server.isRunning,
          ),
        ),
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
            icon: Icon(Icons.delete, size: 15),
          ),
        ),
      ],
    );
  }
}
