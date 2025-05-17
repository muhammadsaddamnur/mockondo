import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:json_field_editor/json_field_editor.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/code_find.dart';
import 'package:mockondo/core/widgets/code_menu.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/languages/json.dart';

class CustomJsonTextField extends StatefulWidget {
  final JsonTextFieldController? controller;
  final String? hintText;
  final IconData? prefixIcon;
  final bool readOnly;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final double textSize;

  const CustomJsonTextField({
    super.key,
    this.controller,
    this.hintText,
    this.prefixIcon,
    this.isPassword = false,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.textSize = 16, // default 16
  });

  @override
  State<CustomJsonTextField> createState() => _CustomJsonTextFieldState();
}

class _CustomJsonTextFieldState extends State<CustomJsonTextField> {
  CodeLineEditingController controller = CodeLineEditingController();

  CodeLines toCodeLines(String input) {
    final lines = input.split('\n');
    // Setiap baris dibungkus jadi CodeLine, lalu jadi CodeLineSegment (karena segmen punya list of CodeLine)
    final segments =
        lines
            .map((line) => CodeLineSegment(codeLines: [CodeLine(line)]))
            .toList();
    return CodeLines(segments);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Color(0xff3e3e42).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: () {
              try {
                // Ambil teks dari controller
                final rawText = controller.codeLines.segments
                    .expand((e) => e)
                    .map((e) => e.text)
                    .join('\n');

                // Parse JSON dari string
                final jsonObject = json.decode(rawText);

                // Encode ulang dengan indentasi supaya rapi
                final prettyString = const JsonEncoder.withIndent(
                  '  ',
                ).convert(jsonObject);

                // Ubah string jadi CodeLines untuk controller
                final beautifiedCodeLines = toCodeLines(prettyString);

                // Update controller
                setState(() {
                  controller.codeLines = beautifiedCodeLines;
                });
              } catch (e) {
                // Kalau gagal parse, tampilkan error atau abaikan
                print('JSON format error: $e');
              }
            },
            child: Text('Beautify', style: TextStyle(fontSize: 10)),
          ),
          Expanded(
            child: CodeEditor(
              controller: controller,
              readOnly: widget.readOnly,
              onChanged: (value) {
                final res = value.codeLines.segments
                    .expand((e) => e)
                    .join('\n');
                widget.onChanged!(res);
              },
              findBuilder:
                  (context, controller, readOnly) => CodeFindPanelView(
                    controller: controller,
                    readOnly: readOnly,
                  ),
              toolbarController: const ContextMenuControllerImpl(),
              indicatorBuilder: (
                context,
                editingController,
                chunkController,
                notifier,
              ) {
                return Row(
                  children: [
                    DefaultCodeLineNumber(
                      controller: editingController,
                      notifier: notifier,
                      focusedTextStyle: TextStyle(
                        color:
                            editingController.isEmpty
                                ? Colors.transparent
                                : AppColors.textD,
                      ),
                      textStyle: TextStyle(
                        color:
                            editingController.isEmpty
                                ? Colors.transparent
                                : AppColors.textD,
                      ),
                    ),
                    DefaultCodeChunkIndicator(
                      width: 20,
                      controller: chunkController,
                      notifier: notifier,
                    ),
                  ],
                );
              },
              style: CodeEditorStyle(
                codeTheme: CodeHighlightTheme(
                  languages: {'json': CodeHighlightThemeMode(mode: langJson)},
                  theme: atomOneLightTheme,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    // return JsonField(
    //   controller: controller,
    //   obscureText: isPassword,
    //   keyboardType: TextInputType.multiline,
    //   onChanged: onChanged,
    //   readOnly: readOnly,
    //   style: TextStyle(fontSize: textSize, color: AppColors.textD),
    //   cursorHeight: textSize,
    //   maxLines: 10,
    //   commonTextStyle: TextStyle(fontSize: textSize, color: AppColors.textD),
    //   decoration: InputDecoration(
    //     prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
    //     hintText: hintText,
    //     filled: true,
    //     fillColor: Color(0xff3e3e42).withValues(alpha: 0.5),
    //     hintStyle: TextStyle(
    //       fontSize: textSize * 0.95,
    //       color: AppColors.textD.withValues(alpha: 0.5),
    //     ),
    //     contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    //     border: OutlineInputBorder(
    //       borderRadius: BorderRadius.circular(5),
    //       borderSide: BorderSide.none,
    //     ),
    //   ),
    // );
  }
}
