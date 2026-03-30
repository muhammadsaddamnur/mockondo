import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/home/presentation/widgets/rules_dialog_widget.dart';

/// Displays the list of conditional response rules for a single endpoint and
/// provides buttons to add, edit, and delete them.
///
/// When [readOnly] is `true` (e.g. while the server is running) editing is
/// disabled; the edit button becomes a view-only icon.
class RulesWidget extends StatefulWidget {
  const RulesWidget({
    super.key,
    required this.endpointIndex,
    required this.readOnly,
  });

  /// Index of the endpoint in the active project's `mockModels` list.
  final int endpointIndex;

  /// Prevents adding or deleting rules when `true`.
  final bool readOnly;

  @override
  State<RulesWidget> createState() => _RulesWidgetState();
}

class _RulesWidgetState extends State<RulesWidget> {
  final homeController = Get.find<HomeController>();

  /// Live list of response rules for the current endpoint.
  List<Rules> get rules =>
      homeController.getResponseRules(widget.endpointIndex);

  /// Opens the rule editor dialog. Passes [existing] when editing.
  void _openEditor({Rules? existing}) {
    showDialog(
      context: context,
      builder: (_) => RuleEditorDialog(
        endpointIndex: widget.endpointIndex,
        existingRule: existing,
        readOnly: widget.readOnly,
      ),
    ).then((_) => setState(() {}));
  }

  /// Deletes [rule] from the endpoint and refreshes the widget.
  void _delete(Rules rule) {
    homeController.removeResponseRule(
      widget.endpointIndex,
      rule.rules['id'] as String,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ruleList = rules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Response Rules',
                    style: TextStyle(
                      color: AppColors.textD,
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Rules are evaluated in order. The first matching rule overrides the default response.',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.6),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                ],
              ),
            ),
            if (!widget.readOnly)
              ElevatedButton.icon(
                onPressed: () => _openEditor(),
                style: ButtonStyle(elevation: WidgetStatePropertyAll(0)),
                icon: const Icon(Icons.add, size: 14),
                label: const Text(
                  'Add Rule',
                  style: TextStyle(fontSize: AppTextSize.body),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (ruleList.isEmpty)
          // Empty-state placeholder
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.rule_folder_outlined,
                    size: 32,
                    color: AppColors.textD.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No rules yet',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.4),
                      fontSize: AppTextSize.body,
                    ),
                  ),
                  Text(
                    'Add a rule to conditionally return different responses.',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.3),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.separated(
              itemCount: ruleList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final rule = ruleList[index];
                return _RuleCard(
                  rule: rule,
                  index: index,
                  readOnly: widget.readOnly,
                  onEdit: () => _openEditor(existing: rule),
                  onDelete: () => _delete(rule),
                );
              },
            ),
          ),
      ],
    );
  }
}

// ── Rule card ──────────────────────────────────────────────────────────────────

/// A compact card representing a single [Rules] entry.
///
/// Shows the rule's priority badge, label, status code, logic badge (AND/OR),
/// a preview of up to 3 conditions, and edit/delete action buttons.
class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.index,
    required this.readOnly,
    required this.onEdit,
    required this.onDelete,
  });

  final Rules rule;

  /// Zero-based position in the rules list, displayed as 1-based priority.
  final int index;

  final bool readOnly;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Short display labels for each condition target type.
  static const _targetLabels = {
    'queryParam': 'query',
    'requestHeader': 'header',
    'bodyField': 'body',
    'routeParam': 'route',
  };

  /// Short display labels for each condition operator.
  static const _operatorLabels = {
    'equals': '==',
    'notEquals': '!=',
    'contains': 'contains',
    'notContains': '!contains',
    'regexMatch': '~regex',
    'isEmpty': 'is empty',
    'isNotEmpty': 'not empty',
  };

  @override
  Widget build(BuildContext context) {
    final conditions = rule.conditions;
    final logic = rule.logic == RulesLogic.or ? 'ANY' : 'ALL';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.textD.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority badge (1-based)
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.textD.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.textD,
                  fontSize: AppTextSize.badge,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.l),

          // Rule summary
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rule.label.isEmpty ? 'Unnamed Rule' : rule.label,
                      style: TextStyle(
                        color: AppColors.textD,
                        fontSize: AppTextSize.body,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.m),
                    _Badge(
                      text: rule.ruleStatusCode.toString(),
                      color: _statusColor(rule.ruleStatusCode),
                    ),
                    // Only show the logic badge when there are multiple conditions.
                    if (conditions.length > 1) ...[
                      const SizedBox(width: 4),
                      _Badge(
                        text: logic,
                        color: AppColors.textD.withValues(alpha: 0.4),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Show up to 3 conditions as monospace text
                ...conditions.take(3).map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      '${_targetLabels[c.target.name] ?? c.target.name}.${c.key} '
                      '${_operatorLabels[c.operator.name] ?? c.operator.name}'
                      '${_hasValue(c.operator) ? ' "${c.value}"' : ''}',
                      style: TextStyle(
                        color: AppColors.textD.withValues(alpha: 0.6),
                        fontSize: AppTextSize.small,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
                if (conditions.length > 3)
                  Text(
                    '+${conditions.length - 3} more condition(s)',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.4),
                      fontSize: AppTextSize.badge,
                    ),
                  ),
              ],
            ),
          ),

          // Action buttons (edit / delete)
          Row(
            children: [
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(
                    readOnly
                        ? Icons.visibility_outlined
                        : Icons.edit_outlined,
                    size: 14,
                    color: AppColors.textD.withValues(alpha: 0.7),
                  ),
                ),
              ),
              if (!readOnly) ...[
                const SizedBox(width: 2),
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      Icons.delete_outline,
                      size: 14,
                      color: AppColors.red.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Returns `false` for operators that don't use a comparison value
  /// (isEmpty / isNotEmpty), so the value is omitted from the preview.
  bool _hasValue(ResponseRuleOperator op) =>
      op != ResponseRuleOperator.isEmpty &&
      op != ResponseRuleOperator.isNotEmpty;

  Color _statusColor(int code) {
    if (code >= 200 && code < 300) return AppColors.greenD;
    if (code >= 400 && code < 500) return Colors.orangeAccent;
    if (code >= 500) return Colors.redAccent;
    return AppColors.textD.withValues(alpha: 0.5);
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────────

/// A small pill-shaped label used inside rule cards (status code, logic type).
class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: AppTextSize.badge,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
