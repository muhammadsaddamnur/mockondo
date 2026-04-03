import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/curl_utils.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/core/widgets/interpolation_textfield.dart';
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

  @override
  void dispose() {
    endpointController.dispose();
    statusCodeController.dispose();
    delayCodeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final mock = homeController
        .mockModels[homeController.selectedMockModelIndex.value]
        ?.mockModels[widget.endpointIndex];

    endpointController.text = mock?.endpoint ?? '';
    statusCodeController.text = (mock?.statusCode ?? 200).toString();
    if (mock?.delay != null) {
      delayCodeController.text = mock!.delay.toString();
    }
  }

  void _showResponseDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ResponseWidget(
          server: homeController
              .mockModels[homeController.selectedMockModelIndex.value]!
              .server!,
          endpointIndex: widget.endpointIndex,
        ),
      ),
    );
  }

  void _showServerRunningSnack() {
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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final serverIsRunning = homeController.serverIsRunning();
      final mock = homeController
          .mockModels[homeController.selectedMockModelIndex.value]
          ?.mockModels[widget.endpointIndex];
      final enabled = mock?.enable ?? false;
      final method = mock?.method ?? 'GET';

      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.m,
          vertical: AppSpacing.s,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceD.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled
                ? AppColors.textD.withValues(alpha: 0.12)
                : AppColors.textD.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Enable checkbox / conflict warning ──────────────────
            if (serverIsRunning && widget.isNotFirstRunning)
              Tooltip(
                message:
                    'This endpoint has the same address as another running endpoint and will be ignored.',
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: colors(context).redDarkness,
                  size: 18,
                ),
              )
            else
              InkWell(
                onTap: serverIsRunning
                    ? _showServerRunningSnack
                    : () => widget.onChangedCheck!(!enabled),
                borderRadius: BorderRadius.circular(4),
                child: Icon(
                  enabled
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: enabled
                      ? colors(context).greenDarkness
                      : AppColors.textD.withValues(alpha: 0.4),
                ),
              ),

            const SizedBox(width: AppSpacing.m),

            // ── Method dropdown ──────────────────────────────────────
            _MethodDropdown(
              value: method,
              readOnly: serverIsRunning,
              onChanged: (v) => widget.onChangedMethod!(v),
            ),

            const SizedBox(width: AppSpacing.s),

            // ── Endpoint path ────────────────────────────────────────
            Expanded(
              child: SizedBox(
                height: 30,
                child: InterpolationTextField(
                  hintText: '/example',
                  controller: endpointController,
                  onChanged: widget.onChangedEndpoint,
                  readOnly: serverIsRunning,
                  textSize: AppTextSize.body,
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.s),

            // ── Status code ──────────────────────────────────────────
            SizedBox(
              width: 70,
              height: 30,
              child: CustomTextField(
                hintText: '200',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: statusCodeController,
                onChanged: widget.onChangedStatusCode,
                readOnly: serverIsRunning,
                textSize: AppTextSize.body,
              ),
            ),

            const SizedBox(width: AppSpacing.s),

            // ── Delay ────────────────────────────────────────────────
            SizedBox(
              width: 90,
              height: 30,
              child: CustomTextField(
                hintText: 'Delay (ms)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                controller: delayCodeController,
                onChanged: widget.onChangedDelay,
                readOnly: serverIsRunning,
                textSize: AppTextSize.body,
              ),
            ),

            const SizedBox(width: AppSpacing.m),

            // ── Response button ──────────────────────────────────────
            SizedBox(
              height: 30,
              child: OutlinedButton(
                onPressed: _showResponseDialog,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppColors.secondaryD.withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: Text(
                  'Response',
                  style: TextStyle(
                    color: AppColors.secondaryD,
                    fontSize: AppTextSize.body,
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.s),

            // ── Copy cURL ────────────────────────────────────────────
            InkWell(
              onTap: () {
                final parentMock = homeController
                    .mockModels[homeController.selectedMockModelIndex.value];
                final port = parentMock?.port ?? 8080;
                final ip = homeController.ipAddress.value;
                final baseUrl = ip.isNotEmpty ? 'http://$ip:$port' : 'http://localhost:$port';
                final url = '$baseUrl${mock?.endpoint ?? ''}';
                final curl = CurlUtils.generate(method: method, url: url);
                Clipboard.setData(ClipboardData(text: curl));
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.content_copy_rounded,
                  size: 14,
                  color: AppColors.textD.withValues(alpha: 0.5),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.xs),

            // ── Delete ───────────────────────────────────────────────
            InkWell(
              onTap: serverIsRunning ? _showServerRunningSnack : widget.onDelete,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: serverIsRunning
                      ? AppColors.textD.withValues(alpha: 0.2)
                      : AppColors.textD.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── Method dropdown ───────────────────────────────────────────────────────────

class _MethodDropdown extends StatelessWidget {
  const _MethodDropdown({
    required this.value,
    required this.readOnly,
    required this.onChanged,
  });

  final String value;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  static const _methods = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const SizedBox.shrink(),
          dropdownColor: AppColors.backgroundD,
          items: _methods
              .map(
                (m) => DropdownMenuItem(
                  value: m,
                  child: Text(
                    m,
                    style: TextStyle(
                      color: AppColors.methodColor(m),
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (_) => _methods
              .map(
                (m) => Center(
                  child: Text(
                    m,
                    style: TextStyle(
                      color: AppColors.methodColor(m),
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: readOnly ? null : (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}
