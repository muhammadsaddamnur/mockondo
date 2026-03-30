import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/server.dart';
import 'package:mockondo/core/widgets/app_tab_bar.dart';
import 'package:mockondo/core/widgets/custom_json_textfield.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/core/widgets/interpolation_textfield.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/home/presentation/widgets/rules_widget.dart';
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

  int tab = 0;

  final dataPaginationController = CodeLineEditingController();

  OffsetType selectedOffsetType = OffsetType.param;
  OffsetType selectedLimitType = OffsetType.param;

  List<_HeaderRow> headerRows = [];
  final bodyResponseController = CodeLineEditingController();

  final offsetParamController = TextEditingController();
  final customOffsetController = TextEditingController();
  final customLimitController = TextEditingController();
  final limitParamController = TextEditingController();
  final maxController = TextEditingController();

  var isUsePagination = false;

  @override
  void dispose() {
    for (final r in headerRows) {
      r.keyController.dispose();
      r.valueController.dispose();
    }
    bodyResponseController.dispose();
    dataPaginationController.dispose();
    offsetParamController.dispose();
    customOffsetController.dispose();
    customLimitController.dispose();
    limitParamController.dispose();
    maxController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    final mock =
        homeController
            .mockModels[homeController.selectedMockModelIndex.value]
            ?.mockModels[widget.endpointIndex];

    final existingHeader =
        mock?.responseHeader ?? {'Content-Type': 'application/json'};
    headerRows = existingHeader.entries
        .map((e) => _HeaderRow(key: e.key, value: e.value.toString()))
        .toList();
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

    isUsePagination =
        homeController.isPagination(widget.endpointIndex) == null
            ? false
            : true;

    super.initState();
  }

  void _save() {
    if (isUsePagination) {
      homeController.setPagination(
        widget.endpointIndex,
        dataPaginationController.text.removeAllWhitespace.trim(),
        PaginationParams(
          customLimit:
              selectedLimitType.isParam()
                  ? null
                  : int.parse(customLimitController.text.trim()),
          limitParam:
              !selectedLimitType.isParam()
                  ? null
                  : limitParamController.text.trim(),
          customOffset:
              selectedOffsetType.isParam()
                  ? null
                  : int.parse(customOffsetController.text.trim()),
          offsetParam:
              !selectedOffsetType.isParam()
                  ? null
                  : offsetParamController.text.trim(),
          max: int.tryParse(maxController.text.trim()) ?? 0,
        ),
      );
    } else {
      homeController.removePagination(widget.endpointIndex);
    }

    final headers = <String, Object>{};
    for (final r in headerRows) {
      final k = r.keyController.text.trim();
      final v = r.valueController.text.trim();
      if (k.isNotEmpty) headers[k] = v;
    }

    homeController.saveAllResponseConfig(
      endpointIndex: widget.endpointIndex,
      responseBody: bodyResponseController.text,
      responseHeader: headers.isEmpty ? null : headers,
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Container(
      width: (size.width * 0.75).clamp(640, 1100),
      height: (size.height * 0.80).clamp(500, 800),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.backgroundD,
        borderRadius: BorderRadius.circular(AppSpacing.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Row(
            children: [
              Icon(Icons.http_rounded, size: 16, color: AppColors.secondaryD),
              const SizedBox(width: AppSpacing.s),
              Text(
                'Response Configuration',
                style: TextStyle(
                  fontSize: AppTextSize.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textD,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(25),
                onTap: () {
                  bodyResponseController.clearHistory();
                  Navigator.pop(context);
                },
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s),
                  child: Icon(Icons.close, size: 14, color: AppColors.textD),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.m),
          Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
          const SizedBox(height: AppSpacing.m),

          // ── Tabs ────────────────────────────────────────────────────
          AppTabBar(
            tabs: const ['Normal', 'Pagination', 'Rules'],
            selected: tab,
            onTap: (i) => setState(() => tab = i),
          ),
          const SizedBox(height: AppSpacing.m),

          // ── Content ─────────────────────────────────────────────────
          if (tab == 2) ...[
            Expanded(
              child: RulesWidget(
                endpointIndex: widget.endpointIndex,
                readOnly: widget.server.isRunning,
              ),
            ),
          ] else ...[
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: header + body editors
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Response Header',
                          style: TextStyle(
                            color: AppColors.textD,
                            fontSize: AppTextSize.small,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 130),
                          child: SingleChildScrollView(
                            child: _HeadersEditor(
                              rows: headerRows,
                              readOnly: widget.server.isRunning,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.m),
                        Text(
                          'Response Body',
                          style: TextStyle(
                            color: AppColors.textD,
                            fontSize: AppTextSize.small,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Expanded(
                          child: CustomJsonTextField(
                            hintText: 'Response Body',
                            controller: bodyResponseController,
                            onChanged: (c) {},
                            readOnly: widget.server.isRunning,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right: pagination (only when tab == 1)
                  if (tab == 1) ...[
                    const SizedBox(width: AppSpacing.m),
                    Container(
                      width: 1,
                      color: AppColors.textD.withValues(alpha: 0.12),
                    ),
                    const SizedBox(width: AppSpacing.m),
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
                                        fontSize: AppTextSize.small,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Configure your pagination settings here.',
                                      style: TextStyle(
                                        color: AppColors.textD.withValues(alpha: 0.6),
                                        fontSize: AppTextSize.small,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                activeThumbColor: AppColors.greenD,
                                value: isUsePagination,
                                onChanged: (value) =>
                                    setState(() => isUsePagination = value),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.m),

                          if (isUsePagination) ...[
                            _PaginationField(
                              label: 'Query Param for page',
                              hint: "e.g. 'page'  (…?page=1&limit=10)",
                              controller: offsetParamController,
                              readOnly: widget.server.isRunning,
                            ),
                            Divider(
                              height: AppSpacing.xl,
                              color: AppColors.textD.withValues(alpha: 0.12),
                            ),
                            _PaginationField(
                              label: 'Query Param for limit',
                              hint: "e.g. 'limit'  (…?page=1&limit=10)",
                              controller: limitParamController,
                              readOnly: widget.server.isRunning,
                            ),
                            Divider(
                              height: AppSpacing.xl,
                              color: AppColors.textD.withValues(alpha: 0.12),
                            ),
                            Text(
                              'Total Data',
                              style: TextStyle(
                                color: AppColors.textD,
                                fontSize: AppTextSize.small,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            SizedBox(
                              height: 30,
                              child: CustomTextField(
                                hintText: 'e.g. 100',
                                controller: maxController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                readOnly: widget.server.isRunning,
                                textSize: AppTextSize.body,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.m),
                            Text(
                              'Data to return per page',
                              style: TextStyle(
                                color: AppColors.textD,
                                fontSize: AppTextSize.small,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            CustomJsonTextField(
                              hintText: 'Input here!',
                              controller: dataPaginationController,
                              onChanged: (data) {},
                              readOnly: widget.server.isRunning,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // ── Footer ──────────────────────────────────────────────────
          const SizedBox(height: AppSpacing.m),
          Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
          const SizedBox(height: AppSpacing.m),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textD,
                    fontSize: AppTextSize.body,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.m),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(elevation: 0),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: AppTextSize.body),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Header row model ──────────────────────────────────────────────────────────

class _HeaderRow {
  final TextEditingController keyController;
  final TextEditingController valueController;

  _HeaderRow({String key = '', String value = ''})
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);
}

// ── Headers key-value editor ──────────────────────────────────────────────────

class _HeadersEditor extends StatelessWidget {
  const _HeadersEditor({
    required this.rows,
    required this.readOnly,
    required this.onChanged,
  });

  final List<_HeaderRow> rows;
  final bool readOnly;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(rows.length, (i) {
          final row = rows[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: InterpolationTextField(
                      controller: row.keyController,
                      hintText: 'Header name',
                      textSize: AppTextSize.small,
                      readOnly: readOnly,
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: InterpolationTextField(
                      controller: row.valueController,
                      hintText: 'Value',
                      textSize: AppTextSize.small,
                      readOnly: readOnly,
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                ),
                if (!readOnly)
                  InkWell(
                    onTap: () {
                      row.keyController.dispose();
                      row.valueController.dispose();
                      rows.removeAt(i);
                      onChanged();
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      child: Icon(
                        Icons.close,
                        size: 12,
                        color: AppColors.textD.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }),
        if (!readOnly)
          InkWell(
            onTap: () {
              rows.add(_HeaderRow());
              onChanged();
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 13, color: AppColors.greenD),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: AppColors.greenD,
                      fontSize: AppTextSize.small,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── Helper sub-widget ──────────────────────────────────────────────────────────

class _PaginationField extends StatelessWidget {
  const _PaginationField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.readOnly,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.textD,
            fontSize: AppTextSize.small,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          hint,
          style: TextStyle(
            color: AppColors.textD.withValues(alpha: 0.5),
            fontSize: AppTextSize.badge,
          ),
        ),
        const SizedBox(height: AppSpacing.s),
        SizedBox(
          height: 30,
          child: InterpolationTextField(
            controller: controller,
            hintText: 'Input here!',
            readOnly: readOnly,
            textSize: AppTextSize.body,
          ),
        ),
      ],
    );
  }
}
