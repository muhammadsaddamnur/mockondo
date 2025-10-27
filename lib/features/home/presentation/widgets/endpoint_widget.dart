import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/home/presentation/widgets/response_widget.dart';

class EndpointWidget extends StatefulWidget {
  final void Function(bool?)? onChangedCheck;
  final void Function(String)? onChangedEndpoint;
  final void Function(String)? onChangedStatusCode;
  final void Function(String)? onChangedMethod;
  final void Function(String)? onChangedDelay;
  final void Function()? onDelete;
  final bool isNotFirstRunning;
  final int endpointIndex;

  const EndpointWidget({
    super.key,
    required this.onChangedCheck,
    required this.onChangedEndpoint,
    required this.onChangedStatusCode,
    required this.onChangedMethod,
    required this.onChangedDelay,
    required this.onDelete,
    this.isNotFirstRunning = false,
    required this.endpointIndex,
  });

  @override
  State<EndpointWidget> createState() => _EndpointWidgetState();
}

class _EndpointWidgetState extends State<EndpointWidget> {
  final homeController = Get.find<HomeController>();

  final endpointController = TextEditingController();
  final statusCodeController = TextEditingController();
  final delayCodeController = TextEditingController();
  bool showResponse = false;

  @override
  void dispose() {
    endpointController.dispose();
    statusCodeController.dispose();
    delayCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    endpointController.clear();
    statusCodeController.clear();
    delayCodeController.clear();

    final mock =
        homeController
            .mockModels[homeController.selectedMockModelIndex.value]
            ?.mockModels[widget.endpointIndex];

    endpointController.text = mock?.endpoint ?? '';
    statusCodeController.text = (mock?.statusCode).toString();
    if (mock?.delay != null) {
      delayCodeController.text = (mock?.delay).toString();
    }

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
    return Obx(() {
      final serverIsRunning = homeController.serverIsRunning();

      final mock =
          homeController
              .mockModels[homeController.selectedMockModelIndex.value]
              ?.mockModels[widget.endpointIndex];
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (serverIsRunning && widget.isNotFirstRunning) ...[
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
                        serverIsRunning
                            ? null
                            : () {
                              widget.onChangedCheck!(!(mock?.enable ?? false));
                            },
                    icon: Icon(
                      (mock?.enable ?? false)
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      color:
                          (mock?.enable ?? false)
                              ? colors(context).greenDarkness
                              : null,
                    ),
                  ),
                ),
              ],
              Expanded(
                child: SizedBox(
                  height: 30,
                  child: CustomTextField(
                    hintText: '/example',
                    controller: endpointController,
                    onChanged: widget.onChangedEndpoint,
                    readOnly: serverIsRunning,
                  ),
                ),
                // child: InkWell(
                //   borderRadius: BorderRadius.circular(5),
                //   onTap: () {},
                //   child: Container(
                //     width: 100,
                //     height: 30,
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(5),
                //       color: Color(0xff3e3e42).withValues(alpha: 0.5),
                //     ),
                //     child: Align(
                //       alignment: AlignmentGeometry.centerLeft,
                //       child: Padding(
                //         padding: const EdgeInsets.symmetric(horizontal: 8),
                //         child: Text(
                //           '/example',
                //           textAlign: TextAlign.left,
                //           style: TextStyle(
                //             fontSize: 16 * 0.95,
                //             color: AppColors.textD.withValues(alpha: 0.5),
                //           ),
                //         ),
                //       ),
                //     ),
                //   ),
                // ),
              ),
              SizedBox(width: 5),
              SizedBox(
                width: 100,
                height: 30,
                child: InkWell(
                  borderRadius: BorderRadius.circular(5),
                  onTap: () {
                    if (serverIsRunning) {
                      return;
                    }
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
                      (mock?.method).toString(),
                      style: TextStyle(
                        color: getColorMethod((mock?.method).toString()),
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
                  readOnly: serverIsRunning,
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
                  readOnly: serverIsRunning,
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
                      serverIsRunning
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
    });
  }

  void showResponseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (_) => Dialog(
            child: ResponseWidget(
              server:
                  homeController
                      .mockModels[homeController.selectedMockModelIndex.value]!
                      .server!,
              endpointIndex: widget.endpointIndex,
            ),
          ),
    );
  }
}
