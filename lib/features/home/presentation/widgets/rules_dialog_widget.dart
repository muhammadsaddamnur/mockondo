import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/widgets/app_tab_bar.dart';
import 'package:mockondo/core/widgets/button_widget.dart';
import 'package:mockondo/core/widgets/custom_drop_down.dart';
import 'package:mockondo/core/widgets/custom_json_textfield.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/core/widgets/interpolation_textfield.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:re_editor/re_editor.dart';
import 'package:uuid/v4.dart';

class RuleEditorDialog extends StatefulWidget {
  const RuleEditorDialog({
    super.key,
    required this.endpointIndex,
    this.existingRule,
    required this.readOnly,
  });

  final int endpointIndex;
  final Rules? existingRule;
  final bool readOnly;

  @override
  State<RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<RuleEditorDialog> {
  final homeController = Get.find<HomeController>();

  late String ruleId;
  final labelController = TextEditingController();
  final statusCodeController = TextEditingController();
  final bodyController = CodeLineEditingController();
  RulesLogic logic = RulesLogic.and;
  List<_ConditionRow> conditions = [];
  List<_HeaderRow> headerRows = [];
  int _rightTab = 0; // 0=body, 1=headers

  @override
  void initState() {
    super.initState();
    final rule = widget.existingRule;
    if (rule != null) {
      ruleId = rule.rules['id'] as String? ?? UuidV4().generate();
      labelController.text = rule.label;
      statusCodeController.text = rule.ruleStatusCode.toString();
      bodyController.text = rule.response;
      logic = rule.logic;
      conditions =
          rule.conditions
              .map(
                (c) => _ConditionRow(
                  id: c.id,
                  target: c.target,
                  key: c.key,
                  operator: c.operator,
                  value: c.value,
                ),
              )
              .toList();
      headerRows =
          (rule.responseHeader ?? {}).entries
              .map((e) => _HeaderRow(key: e.key, value: e.value.toString()))
              .toList();
    } else {
      ruleId = UuidV4().generate();
      statusCodeController.text = '200';
      conditions = [_ConditionRow.empty()];
    }
  }

  @override
  void dispose() {
    labelController.dispose();
    statusCodeController.dispose();
    bodyController.dispose();
    for (final r in headerRows) {
      r.keyController.dispose();
      r.valueController.dispose();
    }
    super.dispose();
  }

  void _addCondition() {
    setState(() {
      conditions.add(_ConditionRow.empty());
    });
  }

  void _removeCondition(int index) {
    setState(() {
      conditions.removeAt(index);
    });
  }

  void _save() {
    final conditionMaps =
        conditions
            .map(
              (c) =>
                  ResponseCondition(
                    id: c.id,
                    target: c.target,
                    key: c.keyController.text.trim(),
                    operator: c.operator,
                    value: c.valueController.text.trim(),
                  ).toJson(),
            )
            .toList();

    final headers = <String, Object>{};
    for (final r in headerRows) {
      final k = r.keyController.text.trim();
      final v = r.valueController.text.trim();
      if (k.isNotEmpty) headers[k] = v;
    }

    final rule = Rules(
      type: RulesType.response,
      rules: {
        'id': ruleId,
        'label': labelController.text.trim(),
        'status_code': int.tryParse(statusCodeController.text.trim()) ?? 200,
        'logic': logic.name,
        'conditions': conditionMaps,
      },
      response: bodyController.text,
      responseHeader: headers.isEmpty ? null : headers,
    );

    homeController.addOrUpdateResponseRule(widget.endpointIndex, rule);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.sizeOf(context).width / 1.3,
        height: MediaQuery.sizeOf(context).height / 1.2,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.backgroundD,
          borderRadius: BorderRadius.circular(AppSpacing.l),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  widget.existingRule == null
                      ? 'Add Response Rule'
                      : 'Edit Response Rule',
                  style: TextStyle(
                    color: AppColors.textD,
                    fontSize: AppTextSize.title,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(25),
                  onTap: () => Navigator.pop(context),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 14, color: AppColors.textD),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: conditions
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Label + status code
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Rule Label'),
                                  const SizedBox(height: AppSpacing.xs),
                                  SizedBox(
                                    height: 30,
                                    child: InterpolationTextField(
                                      controller: labelController,
                                      hintText: 'e.g. Unauthorized',
                                      textSize: 12,
                                      readOnly: widget.readOnly,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.l),
                            SizedBox(
                              width: 80,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Status'),
                                  const SizedBox(height: AppSpacing.xs),
                                  SizedBox(
                                    height: 30,
                                    child: CustomTextField(
                                      controller: statusCodeController,
                                      hintText: '200',
                                      textSize: 12,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      readOnly: widget.readOnly,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.l),

                        // Logic selector
                        Row(
                          children: [
                            Text(
                              'If ',
                              style: TextStyle(
                                color: AppColors.textD,
                                fontSize: AppTextSize.body,
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              height: 30,
                              child: CustomDropDown<RulesLogic>(
                                value: logic,
                                items: const [
                                  DropdownMenuItem(
                                    value: RulesLogic.and,
                                    child: Text(
                                      'ALL',
                                      style: TextStyle(
                                        fontSize: AppTextSize.body,
                                      ),
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: RulesLogic.or,
                                    child: Text(
                                      'ANY',
                                      style: TextStyle(
                                        fontSize: AppTextSize.body,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged:
                                    widget.readOnly
                                        ? null
                                        : (v) => setState(() => logic = v!),
                              ),
                            ),
                            Text(
                              ' of these conditions match:',
                              style: TextStyle(
                                color: AppColors.textD,
                                fontSize: AppTextSize.body,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.m),

                        // Conditions list
                        Expanded(
                          child: ListView.builder(
                            itemCount: conditions.length,
                            itemBuilder: (context, i) {
                              final c = conditions[i];
                              return _ConditionRowWidget(
                                key: ValueKey(c.id),
                                row: c,
                                readOnly: widget.readOnly,
                                onRemove:
                                    conditions.length > 1
                                        ? () => _removeCondition(i)
                                        : null,
                                onChanged: () => setState(() {}),
                              );
                            },
                          ),
                        ),

                        if (!widget.readOnly) ...[
                          const SizedBox(height: AppSpacing.m),
                          InkWell(
                            onTap: _addCondition,
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.m,
                                vertical: AppSpacing.xs,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.add,
                                    size: 14,
                                    color: AppColors.greenD,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    'Add Condition',
                                    style: TextStyle(
                                      color: AppColors.greenD,
                                      fontSize: AppTextSize.body,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    color: AppColors.textD.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 12),

                  // Right: response body + headers tabs
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppTabBar(
                              tabs: [
                                'Body',
                                'Headers (${headerRows.where((r) => r.keyController.text.trim().isNotEmpty).length})',
                              ],
                              selected: _rightTab,
                              onTap: (i) => setState(() => _rightTab = i),
                            ),
                            const Spacer(),
                            if (!widget.readOnly)
                              _EndpointPickerButton(
                                onSelected: (endpoint) {
                                  setState(() {
                                    statusCodeController.text =
                                        endpoint.statusCode.toString();
                                    bodyController.text = endpoint.responseBody;
                                    for (final r in headerRows) {
                                      r.keyController.dispose();
                                      r.valueController.dispose();
                                    }
                                    headerRows =
                                        (endpoint.responseHeader ?? {}).entries
                                            .map(
                                              (e) => _HeaderRow(
                                                key: e.key,
                                                value: e.value.toString(),
                                              ),
                                            )
                                            .toList();
                                  });
                                },
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (_rightTab == 0)
                          Expanded(
                            child: CustomJsonTextField(
                              hintText: 'Response body...',
                              controller: bodyController,
                              onChanged: (_) {},
                              readOnly: widget.readOnly,
                            ),
                          )
                        else
                          Expanded(
                            child: _HeadersEditor(
                              rows: headerRows,
                              readOnly: widget.readOnly,
                              onChanged: () => setState(() {}),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.l),
            if (!widget.readOnly)
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
                  const SizedBox(width: 8),
                  ButtonWidget(
                    onTap: () async {
                      _save();
                    },
                    color: AppColors.secondaryD,
                    child: const Text('Save Rule'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: TextStyle(color: AppColors.textD, fontSize: AppTextSize.small),
  );
}

// ── Header row model ─────────────────────────────────────────────────────────

class _HeaderRow {
  final TextEditingController keyController;
  final TextEditingController valueController;

  _HeaderRow({String key = '', String value = ''})
    : keyController = TextEditingController(text: key),
      valueController = TextEditingController(text: value);
}

// ── Headers editor ────────────────────────────────────────────────────────────

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
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: rows.length,
            itemBuilder: (_, i) {
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
            },
          ),
        ),
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

// ── Endpoint picker button ───────────────────────────────────────────────────

class _EndpointPickerButton extends StatelessWidget {
  const _EndpointPickerButton({required this.onSelected});
  final ValueChanged<MockModel> onSelected;

  @override
  Widget build(BuildContext context) {
    final homeController = Get.find<HomeController>();
    final endpoints =
        homeController
            .mockModels[homeController.selectedMockModelIndex.value]
            ?.mockModels ??
        [];

    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () {
        if (endpoints.isEmpty) return;
        final renderBox = context.findRenderObject() as RenderBox;
        final offset = renderBox.localToGlobal(Offset.zero);
        showMenu<MockModel>(
          context: context,
          color: AppColors.backgroundD,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + renderBox.size.height,
            offset.dx + 200,
            offset.dy,
          ),
          items:
              endpoints.map((e) {
                return PopupMenuItem<MockModel>(
                  value: e,
                  child: Row(
                    children: [
                      Text(
                        e.method,
                        style: TextStyle(
                          color: AppColors.methodColor(e.method),
                          fontSize: AppTextSize.badge,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Expanded(
                        child: Text(
                          e.endpoint,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textD,
                            fontSize: AppTextSize.small,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s),
                      Text(
                        e.statusCode.toString(),
                        style: TextStyle(
                          color: AppColors.textD.withValues(alpha: 0.5),
                          fontSize: AppTextSize.badge,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
        ).then((selected) {
          if (selected != null) onSelected(selected);
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_rounded, size: 12, color: AppColors.secondaryD),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'From endpoint',
              style: TextStyle(
                color: AppColors.secondaryD,
                fontSize: AppTextSize.badge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Condition row state ──────────────────────────────────────────────────────

class _ConditionRow {
  final String id;
  ResponseRuleTarget target;
  final TextEditingController keyController;
  ResponseRuleOperator operator;
  final TextEditingController valueController;

  _ConditionRow({
    required this.id,
    required this.target,
    required String key,
    required this.operator,
    required String value,
  }) : keyController = TextEditingController(text: key),
       valueController = TextEditingController(text: value);

  factory _ConditionRow.empty() => _ConditionRow(
    id: UuidV4().generate(),
    target: ResponseRuleTarget.queryParam,
    key: '',
    operator: ResponseRuleOperator.equals,
    value: '',
  );

  String get key => keyController.text;
  String get value => valueController.text;
}

class _ConditionRowWidget extends StatefulWidget {
  const _ConditionRowWidget({
    super.key,
    required this.row,
    required this.readOnly,
    required this.onChanged,
    this.onRemove,
  });

  final _ConditionRow row;
  final bool readOnly;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  State<_ConditionRowWidget> createState() => _ConditionRowWidgetState();
}

class _ConditionRowWidgetState extends State<_ConditionRowWidget> {
  bool get _hasValue =>
      widget.row.operator != ResponseRuleOperator.isEmpty &&
      widget.row.operator != ResponseRuleOperator.isNotEmpty;

  static const _targetLabels = {
    ResponseRuleTarget.queryParam: 'Query Param',
    ResponseRuleTarget.requestHeader: 'Header',
    ResponseRuleTarget.bodyField: 'Body Field',
    ResponseRuleTarget.routeParam: 'Route Param',
  };

  static const _operatorLabels = {
    ResponseRuleOperator.equals: 'Equals',
    ResponseRuleOperator.notEquals: 'Not Equals',
    ResponseRuleOperator.contains: 'Contains',
    ResponseRuleOperator.notContains: 'Not Contains',
    ResponseRuleOperator.regexMatch: 'Regex',
    ResponseRuleOperator.isEmpty: 'Is Empty',
    ResponseRuleOperator.isNotEmpty: 'Is Not Empty',
  };

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          // Target dropdown
          SizedBox(
            width: 110,
            height: 30,
            child: CustomDropDown<ResponseRuleTarget>(
              value: row.target,
              items:
                  ResponseRuleTarget.values
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(
                            _targetLabels[t]!,
                            style: const TextStyle(fontSize: AppTextSize.small),
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  widget.readOnly
                      ? null
                      : (v) => setState(() => row.target = v!),
            ),
          ),
          const SizedBox(width: 6),

          // Key input
          Expanded(
            child: SizedBox(
              height: 30,
              child: InterpolationTextField(
                controller: row.keyController,
                hintText: 'key',
                textSize: 11,
                readOnly: widget.readOnly,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Operator dropdown
          SizedBox(
            width: 110,
            height: 30,
            child: CustomDropDown<ResponseRuleOperator>(
              value: row.operator,
              items:
                  ResponseRuleOperator.values
                      .map(
                        (o) => DropdownMenuItem(
                          value: o,
                          child: Text(
                            _operatorLabels[o]!,
                            style: const TextStyle(fontSize: AppTextSize.small),
                          ),
                        ),
                      )
                      .toList(),
              onChanged:
                  widget.readOnly
                      ? null
                      : (v) => setState(() => row.operator = v!),
            ),
          ),

          // Value input (hidden for isEmpty/isNotEmpty)
          if (_hasValue) ...[
            const SizedBox(width: 6),
            Expanded(
              child: SizedBox(
                height: 30,
                child: InterpolationTextField(
                  controller: row.valueController,
                  hintText: 'value',
                  textSize: 11,
                  readOnly: widget.readOnly,
                ),
              ),
            ),
          ],

          // Remove button
          if (widget.onRemove != null) ...[
            const SizedBox(width: AppSpacing.xs),
            InkWell(
              onTap: widget.onRemove,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 12,
                  color: AppColors.textD.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
