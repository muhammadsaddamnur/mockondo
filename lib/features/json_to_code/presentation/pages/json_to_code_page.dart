import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/features/json_to_code/core/lang_settings.dart';
import 'package:mockondo/features/json_to_code/presentation/controllers/json_to_code_controller.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';

class JsonToCodePage extends StatelessWidget {
  const JsonToCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(JsonToCodeController());

    return Row(
      children: [
        // ── Left panel: JSON input ─────────────────────────────────────────
        SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelHeader(
                icon: Icons.data_object,
                title: 'JSON Input',
                trailing: SizedBox(
                  height: 28,
                  child: ElevatedButton.icon(
                    onPressed: ctrl.generate,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m),
                    ),
                    icon: const Icon(Icons.auto_fix_high, size: 14),
                    label: const Text(
                      'Generate',
                      style: TextStyle(fontSize: AppTextSize.body),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) => _JsonInputEditor(
                    controller: ctrl.inputCtrl,
                    height: constraints.maxHeight,
                  ),
                ),
              ),
              Obx(() {
                final err = ctrl.errorMessage.value;
                if (err == null) return const SizedBox.shrink();
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.m, vertical: AppSpacing.s),
                  color: Colors.red.withValues(alpha: 0.12),
                  child: Text(
                    err,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: AppTextSize.small,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        VerticalDivider(
          width: 1,
          color: AppColors.textD.withValues(alpha: 0.1),
        ),

        // ── Right panel: generated output ──────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _panelHeader(
                icon: Icons.code,
                title: 'Generated Code',
                trailing: Row(
                  children: [
                    // Language chips
                    Obx(() => Row(
                          children: JsonToCodeController.languages
                              .map((lang) => _LangChip(
                                    label: lang,
                                    selected:
                                        ctrl.selectedLanguage.value == lang,
                                    onTap: () => ctrl.selectLanguage(lang),
                                  ))
                              .toList(),
                        )),
                    const SizedBox(width: AppSpacing.xs),
                    // Settings
                    Tooltip(
                      message: 'Language settings',
                      child: InkWell(
                        onTap: () => _showSettings(context, ctrl),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            Icons.tune_rounded,
                            size: 15,
                            color: AppColors.textD.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    // Copy
                    Tooltip(
                      message: 'Copy code',
                      child: InkWell(
                        onTap: () {
                          final text = ctrl.outputCtrl.text;
                          if (text.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: text));
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          child: Icon(
                            Icons.content_copy_rounded,
                            size: 15,
                            color: AppColors.textD.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, constraints) => _OutputEditor(
                    ctrl: ctrl.outputCtrl,
                    height: constraints.maxHeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSettings(BuildContext context, JsonToCodeController ctrl) {
    showDialog<void>(
      context: context,
      builder: (_) => _SettingsDialog(ctrl: ctrl),
    );
  }

  Widget _panelHeader({
    required IconData icon,
    required String title,
    required Widget trailing,
  }) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.m),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.textD.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textD.withValues(alpha: 0.55)),
          const SizedBox(width: AppSpacing.s),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.7),
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }
}

// ── Settings dialog ───────────────────────────────────────────────────────────

class _SettingsDialog extends StatelessWidget {
  const _SettingsDialog({required this.ctrl});

  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceD,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.l, AppSpacing.m, AppSpacing.m, AppSpacing.s),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      size: 15,
                      color: AppColors.textD.withValues(alpha: 0.55)),
                  const SizedBox(width: AppSpacing.s),
                  Text(
                    'Language Settings',
                    style: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.85),
                      fontSize: AppTextSize.body,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close,
                        size: 15,
                        color: AppColors.textD.withValues(alpha: 0.45)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Divider(
                height: 1, color: AppColors.textD.withValues(alpha: 0.08)),
            // Content
            Obx(() {
              final lang = ctrl.selectedLanguage.value;
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: switch (lang) {
                  'Dart' => _DartSettingsPanel(ctrl: ctrl),
                  'TypeScript' => _TypeScriptSettingsPanel(ctrl: ctrl),
                  'Kotlin' => _KotlinSettingsPanel(ctrl: ctrl),
                  'Swift' => _SwiftSettingsPanel(ctrl: ctrl),
                  'Python' => _PythonSettingsPanel(ctrl: ctrl),
                  'Go' => _GoSettingsPanel(ctrl: ctrl),
                  _ => const SizedBox.shrink(),
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Settings panels ───────────────────────────────────────────────────────────

class _DartSettingsPanel extends StatelessWidget {
  const _DartSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.dartSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            label: 'Null safety',
            description: 'Use nullable types (String?, int?)',
            value: s.nullSafety,
            onChanged: (v) =>
                ctrl.updateDartSettings(s.copyWithValues(nullSafety: v)),
          ),
          _ToggleRow(
            label: 'Immutable fields',
            description: 'Use final instead of var',
            value: s.immutable,
            onChanged: (v) =>
                ctrl.updateDartSettings(s.copyWithValues(immutable: v)),
          ),
          _ToggleRow(
            label: 'copyWith',
            description: 'Generate copyWith method',
            value: s.copyWith,
            onChanged: (v) =>
                ctrl.updateDartSettings(s.copyWithValues(copyWith: v)),
          ),
          _ToggleRow(
            label: 'Equatable',
            description: 'Extend Equatable and generate props',
            value: s.equatable,
            onChanged: (v) =>
                ctrl.updateDartSettings(s.copyWithValues(equatable: v)),
          ),
        ],
      );
    });
  }
}

class _TypeScriptSettingsPanel extends StatelessWidget {
  const _TypeScriptSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.tsSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            label: 'Use type alias',
            description: 'export type Foo = {...} instead of interface',
            value: s.useType,
            onChanged: (v) =>
                ctrl.updateTsSettings(s.copyWithValues(useType: v)),
          ),
          _ToggleRow(
            label: 'Readonly properties',
            description: 'Add readonly modifier to all fields',
            value: s.readonly,
            onChanged: (v) =>
                ctrl.updateTsSettings(s.copyWithValues(readonly: v)),
          ),
          _ToggleRow(
            label: 'undefined instead of null',
            description: 'Use T | undefined instead of T | null',
            value: s.undefinedForNull,
            onChanged: (v) =>
                ctrl.updateTsSettings(s.copyWithValues(undefinedForNull: v)),
          ),
        ],
      );
    });
  }
}

class _KotlinSettingsPanel extends StatelessWidget {
  const _KotlinSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.kotlinSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadioGroupRow<String>(
            label: 'Serialization library',
            options: const ['gson', 'moshi', 'kotlinx'],
            labels: const ['Gson', 'Moshi', 'kotlinx.serialization'],
            value: s.serialization,
            onChanged: (v) => ctrl.updateKotlinSettings(
                s.copyWithValues(serialization: v)),
          ),
          _ToggleRow(
            label: 'Mutable fields',
            description: 'Use var instead of val',
            value: s.mutable,
            onChanged: (v) =>
                ctrl.updateKotlinSettings(s.copyWithValues(mutable: v)),
          ),
        ],
      );
    });
  }
}

class _SwiftSettingsPanel extends StatelessWidget {
  const _SwiftSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.swiftSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            label: 'Use class',
            description: 'Generate class instead of struct',
            value: s.useClass,
            onChanged: (v) =>
                ctrl.updateSwiftSettings(s.copyWithValues(useClass: v)),
          ),
          _RadioGroupRow<String>(
            label: 'Access modifier',
            options: const ['internal', 'public'],
            labels: const ['internal (default)', 'public'],
            value: s.accessLevel,
            onChanged: (v) =>
                ctrl.updateSwiftSettings(s.copyWithValues(accessLevel: v)),
          ),
        ],
      );
    });
  }
}

class _PythonSettingsPanel extends StatelessWidget {
  const _PythonSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.pythonSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadioGroupRow<String>(
            label: 'Style',
            options: const ['dataclass', 'typeddict', 'attrs'],
            labels: const ['@dataclass', 'TypedDict', '@attrs.define'],
            value: s.style,
            onChanged: (v) =>
                ctrl.updatePythonSettings(s.copyWithValues(style: v)),
          ),
          _ToggleRow(
            label: 'Modern union syntax',
            description: 'Use X | None (Python 3.10+) instead of Optional[X]',
            value: s.modernUnion,
            onChanged: (v) =>
                ctrl.updatePythonSettings(s.copyWithValues(modernUnion: v)),
          ),
        ],
      );
    });
  }
}

class _GoSettingsPanel extends StatelessWidget {
  const _GoSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.goSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TextInputRow(
            label: 'Package name',
            value: s.packageName,
            onChanged: (v) =>
                ctrl.updateGoSettings(s.copyWithValues(packageName: v)),
          ),
          _ToggleRow(
            label: 'omitempty',
            description: 'Add omitempty to json struct tags',
            value: s.omitempty,
            onChanged: (v) =>
                ctrl.updateGoSettings(s.copyWithValues(omitempty: v)),
          ),
        ],
      );
    });
  }
}

// ── Settings row widgets ──────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.85),
                    fontSize: AppTextSize.body,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textD.withValues(alpha: 0.4),
                    fontSize: AppTextSize.small,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _RadioGroupRow<T> extends StatelessWidget {
  const _RadioGroupRow({
    required this.label,
    required this.options,
    required this.labels,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final List<T> options;
  final List<String> labels;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.85),
              fontSize: AppTextSize.body,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: List.generate(options.length, (i) {
              final selected = options[i] == value;
              return InkWell(
                onTap: () => onChanged(options[i]),
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.secondaryD.withValues(alpha: 0.15)
                        : AppColors.textD.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: selected
                          ? AppColors.secondaryD.withValues(alpha: 0.45)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: AppTextSize.small,
                      color: selected
                          ? AppColors.secondaryD
                          : AppColors.textD.withValues(alpha: 0.55),
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _TextInputRow extends StatefulWidget {
  const _TextInputRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_TextInputRow> createState() => _TextInputRowState();
}

class _TextInputRowState extends State<_TextInputRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: TextStyle(
                color: AppColors.textD.withValues(alpha: 0.85),
                fontSize: AppTextSize.body,
              ),
            ),
          ),
          SizedBox(
            width: 120,
            height: 28,
            child: TextField(
              controller: _ctrl,
              onChanged: widget.onChanged,
              style: TextStyle(
                color: AppColors.textD.withValues(alpha: 0.85),
                fontSize: AppTextSize.small,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s, vertical: 4),
                isDense: true,
                filled: true,
                fillColor: AppColors.textD.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                      color: AppColors.textD.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                      color: AppColors.textD.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(4),
                  borderSide: BorderSide(
                      color: AppColors.secondaryD.withValues(alpha: 0.6)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lightweight JSON input editor (no autocomplete → no lag) ──────────────────

class _JsonInputEditor extends StatelessWidget {
  const _JsonInputEditor({required this.controller, required this.height});

  final CodeLineEditingController controller;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: AppColors.surfaceD.withValues(alpha: 0.2),
      child: Column(
        children: [
          Expanded(
            child: CodeEditor(
              controller: controller,
              hint: '{\n  "id": 1,\n  "name": "John"\n}',
              style: CodeEditorStyle(
                codeTheme: CodeHighlightTheme(
                  languages: {'json': CodeHighlightThemeMode(mode: langJson)},
                  theme: atomOneDarkTheme,
                ),
                hintTextColor: AppColors.textD.withValues(alpha: 0.25),
                fontSize: AppTextSize.body,
                fontFamily: 'monospace',
                backgroundColor: Colors.transparent,
              ),
              indicatorBuilder: (_, editing, chunk, notifier) => Row(
                children: [
                  DefaultCodeLineNumber(
                    controller: editing,
                    notifier: notifier,
                    textStyle: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.3),
                      fontSize: AppTextSize.small,
                    ),
                    focusedTextStyle: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.5),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                  DefaultCodeChunkIndicator(
                    width: 14,
                    controller: chunk,
                    notifier: notifier,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Language chip ─────────────────────────────────────────────────────────────

class _LangChip extends StatelessWidget {
  const _LangChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: AppSpacing.s, vertical: 3),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.secondaryD.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: selected
                  ? AppColors.secondaryD.withValues(alpha: 0.45)
                  : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTextSize.small,
              color: selected
                  ? AppColors.secondaryD
                  : AppColors.textD.withValues(alpha: 0.45),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Read-only output editor ───────────────────────────────────────────────────

class _OutputEditor extends StatelessWidget {
  const _OutputEditor({required this.ctrl, required this.height});

  final CodeLineEditingController ctrl;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: AppColors.surfaceD.withValues(alpha: 0.2),
      child: Column(
        children: [
          Expanded(
            child: CodeEditor(
              controller: ctrl,
              readOnly: true,
              hint: 'Generated code will appear here…',
              style: CodeEditorStyle(
                codeTheme: CodeHighlightTheme(
                  languages: const {},
                  theme: atomOneDarkTheme,
                ),
                hintTextColor: AppColors.textD.withValues(alpha: 0.25),
                fontSize: AppTextSize.body,
                fontFamily: 'monospace',
                backgroundColor: Colors.transparent,
              ),
              indicatorBuilder: (_, editing, chunk, notifier) => Row(
                children: [
                  DefaultCodeLineNumber(
                    controller: editing,
                    notifier: notifier,
                    textStyle: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.3),
                      fontSize: AppTextSize.small,
                    ),
                    focusedTextStyle: TextStyle(
                      color: AppColors.textD.withValues(alpha: 0.5),
                      fontSize: AppTextSize.small,
                    ),
                  ),
                  DefaultCodeChunkIndicator(
                    width: 14,
                    controller: chunk,
                    notifier: notifier,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
