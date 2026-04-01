import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/code_menu.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
import 'package:re_editor/re_editor.dart';

/// A single-field input dialog used by [CustomDataPage].
///
/// - [title]        — dialog title (default `'Add'`).
/// - [initData]     — pre-fills the field in edit mode.
/// - [isCodeEditor] — when `true` shows a multi-line [CodeEditor] instead of
///                    a single-line [CustomTextField].
/// - [onTap]        — called with the non-empty text when the user taps **Save**.
class InputCustomDialogWidget extends StatefulWidget {
  const InputCustomDialogWidget({
    super.key,
    this.initData,
    this.title,
    this.isCodeEditor = false,
    required this.onTap,
  });

  final String? initData;
  final String? title;
  final bool isCodeEditor;
  final Function(String input) onTap;

  @override
  State<InputCustomDialogWidget> createState() =>
      _InputCustomDialogWidgetState();
}

class _InputCustomDialogWidgetState extends State<InputCustomDialogWidget> {
  TextEditingController? _textCtrl;
  CodeLineEditingController? _codeCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.isCodeEditor) {
      _codeCtrl = CodeLineEditingController.fromText(widget.initData ?? '');
    } else {
      _textCtrl = TextEditingController(text: widget.initData ?? '');
    }
  }

  @override
  void dispose() {
    _textCtrl?.dispose();
    _codeCtrl?.dispose();
    super.dispose();
  }

  String get _currentText {
    if (widget.isCodeEditor) {
      return _codeCtrl!.codeLines.segments
          .expand((s) => s)
          .map((l) => l.text)
          .join('\n');
    }
    return _textCtrl!.text;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundD,
      title: Text(
        widget.title ?? 'Add',
        style: TextStyle(
          color: AppColors.textD,
          fontSize: AppTextSize.title,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: SizedBox(
        width: 440,
        child: widget.isCodeEditor
            ? Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppColors.surfaceD.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: CodeEditor(
                  controller: _codeCtrl!,
                  hint: 'Enter value…',
                  toolbarController: const ContextMenuControllerImpl(),
                  style: CodeEditorStyle(
                    fontSize: AppTextSize.body,
                    hintTextColor: AppColors.textD.withValues(alpha: 0.4),
                    textColor: AppColors.textD,
                    backgroundColor: Colors.transparent,
                  ),
                ),
              )
            : SizedBox(
                height: 40,
                child: CustomTextField(
                  controller: _textCtrl,
                  hintText: 'Enter value…',
                  textSize: AppTextSize.body,
                  onSubmitted: (_) => _save(context),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textD.withValues(alpha: 0.6)),
          ),
        ),
        TextButton(
          onPressed: () => _save(context),
          child: Text(
            'Save',
            style: TextStyle(color: AppColors.secondaryD),
          ),
        ),
      ],
    );
  }

  void _save(BuildContext context) {
    final text = _currentText.trim();
    if (text.isEmpty) return;
    Navigator.pop(context);
    widget.onTap(text);
  }
}
