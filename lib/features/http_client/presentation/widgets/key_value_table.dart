import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:mockondo/core/widgets/interpolation_textfield.dart';
import 'package:mockondo/features/http_client/data/models/http_client_model.dart';

/// Key-value pair editor table for request headers and params.
/// Controllers are properly managed in state to avoid cursor-jump bugs.
class KeyValueTable extends StatefulWidget {
  const KeyValueTable({
    super.key,
    required this.pairs,
    required this.onChanged,
    this.keyHint = 'Key',
    this.valueHint = 'Value',
    this.enableInterpolation = false,
  });

  final List<KeyValuePair> pairs;
  final ValueChanged<List<KeyValuePair>> onChanged;
  final String keyHint;
  final String valueHint;
  final bool enableInterpolation;

  @override
  State<KeyValueTable> createState() => _KeyValueTableState();
}

class _KeyValueTableState extends State<KeyValueTable> {
  final List<TextEditingController> _keyCtrl = [];
  final List<TextEditingController> _valCtrl = [];

  @override
  void initState() {
    super.initState();
    _buildControllers(widget.pairs);
  }

  @override
  void didUpdateWidget(KeyValueTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild controllers only when the list size changes (add/remove row),
    // NOT when typing — so cursor position is preserved during input.
    if (oldWidget.pairs.length != widget.pairs.length) {
      _disposeControllers();
      _buildControllers(widget.pairs);
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  void _buildControllers(List<KeyValuePair> pairs) {
    for (final p in pairs) {
      _keyCtrl.add(TextEditingController(text: p.key));
      _valCtrl.add(TextEditingController(text: p.value));
    }
  }

  void _disposeControllers() {
    for (final c in _keyCtrl) { c.dispose(); }
    for (final c in _valCtrl) { c.dispose(); }
    _keyCtrl.clear();
    _valCtrl.clear();
  }

  List<KeyValuePair> _buildPairs() => List.generate(
        widget.pairs.length,
        (i) => KeyValuePair(
          key: _keyCtrl[i].text,
          value: _valCtrl[i].text,
          enabled: widget.pairs[i].enabled,
        ),
      );

  void _add() => widget.onChanged([...widget.pairs, KeyValuePair()]);

  void _remove(int i) {
    final updated = [...widget.pairs]..removeAt(i);
    widget.onChanged(updated);
  }

  void _toggleEnabled(int i, bool value) {
    final updated = _buildPairs();
    updated[i] = updated[i].copyWith(enabled: value);
    widget.onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Column header row
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const SizedBox(width: 28),
              Expanded(
                child: Text(
                  widget.keyHint,
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.45),
                    fontSize: AppTextSize.badge,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s),
              Expanded(
                child: Text(
                  widget.valueHint,
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.45),
                    fontSize: AppTextSize.badge,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 24),
            ],
          ),
        ),

        // Rows
        ...List.generate(widget.pairs.length, (i) {
          final pair = widget.pairs[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                InkWell(
                  onTap: () => _toggleEnabled(i, !pair.enabled),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: Icon(
                      pair.enabled
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      size: 16,
                      color: pair.enabled
                          ? AppColors.greenD
                          : AppColors.textD.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: CustomTextField(
                      controller: _keyCtrl[i],
                      hintText: widget.keyHint,
                      textSize: AppTextSize.small,
                      onChanged: (_) => widget.onChanged(_buildPairs()),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: widget.enableInterpolation
                        ? InterpolationTextField(
                            controller: _valCtrl[i],
                            hintText: widget.valueHint,
                            textSize: AppTextSize.small,
                            onChanged: (_) => widget.onChanged(_buildPairs()),
                          )
                        : CustomTextField(
                            controller: _valCtrl[i],
                            hintText: widget.valueHint,
                            textSize: AppTextSize.small,
                            onChanged: (_) => widget.onChanged(_buildPairs()),
                          ),
                  ),
                ),
                InkWell(
                  onTap: () => _remove(i),
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

        // Add row button
        InkWell(
          onTap: _add,
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
                  style: TextStyle(color: AppColors.greenD, fontSize: AppTextSize.small),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

