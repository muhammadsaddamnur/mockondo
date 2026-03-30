import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';

/// A minimal single-field text-input dialog.
///
/// Used by [CustomDataDialogWidget] to collect a new key or value name.
/// Pass [initData] to pre-fill the field when editing an existing entry.
/// [onTap] is called with the entered text when the user presses **Save**;
/// it is not called if the field is empty.
class InputCustomDialogWidget extends StatefulWidget {
  const InputCustomDialogWidget({
    super.key,
    this.initData,
    this.keyData,
    required this.onTap,
  });

  /// Pre-filled value shown in the text field (for edit mode).
  final String? initData;

  /// Unused — reserved for future context-aware labelling.
  final String? keyData;

  /// Called with the non-empty input string after the user taps **Save**.
  final Function(String input) onTap;

  @override
  State<InputCustomDialogWidget> createState() =>
      _InputCustomDialogWidgetState();
}

class _InputCustomDialogWidgetState extends State<InputCustomDialogWidget> {
  final controller = TextEditingController();

  @override
  void initState() {
    // Pre-fill with the existing value when editing.
    if (widget.initData != null) controller.text = widget.initData!;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500,
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomTextField(hintText: 'Input Data', controller: controller),
            Padding(
              padding: EdgeInsets.all(AppSpacing.m),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  if (controller.text.isNotEmpty) {
                    widget.onTap(controller.text);
                  }
                },
                child: Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
