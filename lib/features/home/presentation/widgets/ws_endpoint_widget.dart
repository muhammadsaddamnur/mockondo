import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/home/presentation/widgets/ws_response_widget.dart';

/// A single row in the WebSocket endpoint list.
///
/// Shows an enable toggle, the WS badge, an editable path field,
/// a "Config" button that opens [WsResponseWidget], and a delete button.
class WsEndpointWidget extends StatefulWidget {
  final int wsIndex;
  final VoidCallback onDelete;

  const WsEndpointWidget({
    super.key,
    required this.wsIndex,
    required this.onDelete,
  });

  @override
  State<WsEndpointWidget> createState() => _WsEndpointWidgetState();
}

class _WsEndpointWidgetState extends State<WsEndpointWidget> {
  final homeController = Get.find<HomeController>();
  final endpointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final model = homeController
        .mockModels[homeController.selectedMockModelIndex.value]
        ?.wsMockModels[widget.wsIndex];
    endpointController.text = model?.endpoint ?? '/ws';
  }

  @override
  void dispose() {
    endpointController.dispose();
    super.dispose();
  }

  void _openConfig() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: WsResponseWidget(wsIndex: widget.wsIndex),
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
      final model = homeController
          .mockModels[homeController.selectedMockModelIndex.value]
          ?.wsMockModels[widget.wsIndex];
      final enabled = model?.enable ?? false;

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
          children: [
            // Enable toggle
            InkWell(
              onTap: serverIsRunning
                  ? _showServerRunningSnack
                  : () {
                      model?.enable = !enabled;
                      homeController.save();
                      setState(() {});
                    },
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

            // WS badge
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s),
              decoration: BoxDecoration(
                color: const Color(0xFF1A6B5E),
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: const Text(
                'WS',
                style: TextStyle(
                  color: Color(0xFF4DFFD6),
                  fontSize: AppTextSize.body,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.s),

            // Endpoint path
            Expanded(
              child: SizedBox(
                height: 30,
                child: CustomTextField(
                  hintText: '/ws',
                  controller: endpointController,
                  readOnly: serverIsRunning,
                  textSize: AppTextSize.body,
                  onChanged: (value) {
                    model?.endpoint = value;
                    homeController.save();
                  },
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.m),

            // Config button
            SizedBox(
              height: 30,
              child: OutlinedButton(
                onPressed: _openConfig,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: const Color(0xFF4DFFD6).withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                child: const Text(
                  'Config',
                  style: TextStyle(
                    color: Color(0xFF4DFFD6),
                    fontSize: AppTextSize.body,
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.s),

            // Copy ws:// URL
            InkWell(
              onTap: () {
                final parentMock = homeController
                    .mockModels[homeController.selectedMockModelIndex.value];
                final port = parentMock?.port ?? 8080;
                final ip = homeController.ipAddress.value;
                final host = ip.isNotEmpty ? ip : 'localhost';
                final url = 'ws://$host:$port${model?.endpoint ?? ''}';
                Clipboard.setData(ClipboardData(text: url));
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

            // Delete
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
