import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/code_find.dart';
import 'package:mockondo/core/widgets/code_menu.dart';
import 'package:mockondo/core/widgets/interpolation_autocomplete.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/styles/atom-one-light.dart';
import 'package:re_highlight/languages/json.dart';

class CustomJsonTextField extends StatefulWidget {
  final String? hintText;
  final IconData? prefixIcon;
  final bool readOnly;
  final bool isPassword;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final double textSize;
  final CodeLineEditingController controller;
  final double height;

  const CustomJsonTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.isPassword = false,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.height = 200,
    this.textSize = 16, // default 16
  });

  @override
  State<CustomJsonTextField> createState() => _CustomJsonTextFieldState();
}

class _CustomJsonTextFieldState extends State<CustomJsonTextField> {
  static final _promptsBuilder = InterpolationPromptsBuilder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceD.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton(
            onPressed: () {
              try {
                // Ambil teks dari controller
                var rawText = widget.controller.text;

                // Extract dan simpan placeholder interpolasi.
                // Dua kasus:
                //   1. "${...}"  → already quoted  → simpan termasuk quote
                //   2.  ${...}   → bare (angka/array) → simpan tanpa quote, bungkus sementara
                final placeholders = <String, String>{}; // key → original (incl. or excl. quotes)
                var pIdx = 0;

                // Case 1: quoted interpolation  "... ${} ..."
                rawText = rawText.replaceAllMapped(
                  RegExp(r'"([^"]*\$\{[^}]+\}[^"]*)"'),
                  (m) {
                    final key = '__PI${pIdx}__';
                    placeholders[key] = m.group(0)!; // includes outer "
                    pIdx++;
                    return '"$key"';
                  },
                );

                // Case 2: bare interpolation (no surrounding quotes)
                rawText = rawText.replaceAllMapped(
                  RegExp(r'\$\{[^}]+\}'),
                  (m) {
                    final key = '__PI${pIdx}__';
                    placeholders[key] = m.group(0)!; // no outer "
                    pIdx++;
                    return '"$key"'; // wrap in quotes so JSON is valid
                  },
                );

                // Parse JSON dari string (tanpa placeholder)
                final jsonObject = json.decode(rawText);

                // Encode ulang dengan indentasi supaya rapi
                var prettyString = const JsonEncoder.withIndent(
                  '  ',
                ).convert(jsonObject);

                // Restore placeholder kembali
                // Baik case 1 maupun 2, di prettyString muncul sebagai "key"
                // — ganti '"key"' dengan original (yang sudah ada/tidak ada quote)
                placeholders.forEach((key, original) {
                  prettyString = prettyString.replaceAll('"$key"', original);
                });

                // clearHistory dulu supaya re_editor reset internal state,
                // lalu set text baru
                widget.controller.clearHistory();
                widget.controller.text = prettyString;
                widget.onChanged?.call(prettyString);
              } catch (e) {
                // Kalau gagal parse, tampilkan error atau abaikan
                print('JSON format error: $e');
              }
            },
            child: Text('Beautify', style: TextStyle(fontSize: AppTextSize.badge)),
          ),
          Expanded(
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{},
              child: CodeAutocomplete(
              viewBuilder: buildInterpolationAutocompleteView,
              promptsBuilder: _promptsBuilder,
              child: CodeEditor(
              controller: widget.controller,
              readOnly: widget.readOnly,
              hint: widget.hintText,
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
                hintTextColor: AppColors.textD.withValues(alpha: 0.5),
              ),
            ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}
