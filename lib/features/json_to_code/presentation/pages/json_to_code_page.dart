import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/widgets/button_widget.dart';
import 'package:mockondo/core/widgets/custom_textfield.dart';
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
                  child: ButtonWidget(
                    onTap: () async {
                      ctrl.generate();
                    },
                    color: AppColors.secondaryD,
                    child: const Text(
                      'Generate',
                      style: TextStyle(fontSize: AppTextSize.body),
                    ),
                  ),
                ),
              ),
              _NameField(ctrl: ctrl),
              Expanded(
                child: LayoutBuilder(
                  builder:
                      (_, constraints) => _JsonInputEditor(
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
                    horizontal: AppSpacing.m,
                    vertical: AppSpacing.s,
                  ),
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
                    // Language selector button
                    Obx(() => InkWell(
                      onTap: () => _showLanguageDialog(context, ctrl),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryD.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: AppColors.secondaryD.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ctrl.selectedLanguage.value,
                              style: TextStyle(
                                fontSize: AppTextSize.small,
                                color: AppColors.secondaryD,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Icon(Icons.arrow_drop_down, size: 14, color: AppColors.secondaryD),
                          ],
                        ),
                      ),
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
                  builder:
                      (_, constraints) => _OutputEditor(
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

  void _showLanguageDialog(BuildContext context, JsonToCodeController ctrl) {
    showDialog<void>(
      context: context,
      builder: (dlgCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            color: AppColors.backgroundD,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.l, AppSpacing.m, AppSpacing.l),
                child: Row(
                  children: [
                    Icon(Icons.code, size: 16, color: AppColors.textD),
                    const SizedBox(width: AppSpacing.m),
                    Expanded(
                      child: Text(
                        'Select Language',
                        style: TextStyle(
                          color: AppColors.textD,
                          fontSize: AppTextSize.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(dlgCtx),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.s),
                        child: Icon(Icons.close, size: 14, color: AppColors.textD.withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.textD.withValues(alpha: 0.12)),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.m),
                child: Obx(() => Wrap(
                  spacing: AppSpacing.s,
                  runSpacing: AppSpacing.s,
                  children: JsonToCodeController.languages.map((lang) {
                    final selected = ctrl.selectedLanguage.value == lang;
                    return InkWell(
                      onTap: () {
                        ctrl.selectLanguage(lang);
                        Navigator.pop(dlgCtx);
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.m,
                          vertical: AppSpacing.s,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.secondaryD.withValues(alpha: 0.15)
                              : AppColors.surfaceD.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: selected
                                ? AppColors.secondaryD.withValues(alpha: 0.45)
                                : AppColors.textD.withValues(alpha: 0.1),
                          ),
                        ),
                        child: Text(
                          lang,
                          style: TextStyle(
                            fontSize: AppTextSize.body,
                            color: selected
                                ? AppColors.secondaryD
                                : AppColors.textD.withValues(alpha: 0.7),
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                )),
              ),
            ],
          ),
        ),
      ),
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
    return AlertDialog(
      backgroundColor: AppColors.backgroundD,
      title: Row(
        children: [
          Icon(Icons.tune_rounded, size: 15, color: AppColors.secondaryD),
          const SizedBox(width: AppSpacing.s),
          Text(
            'Language Settings',
            style: TextStyle(
              color: AppColors.textD,
              fontSize: AppTextSize.title,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Obx(() {
          final lang = ctrl.selectedLanguage.value;
          return switch (lang) {
            'Dart' => _DartSettingsPanel(ctrl: ctrl),
            'TypeScript' => _TypeScriptSettingsPanel(ctrl: ctrl),
            'JavaScript' => _JavaScriptSettingsPanel(ctrl: ctrl),
            'Kotlin' => _KotlinSettingsPanel(ctrl: ctrl),
            'Java' => _JavaSettingsPanel(ctrl: ctrl),
            'Swift' => _SwiftSettingsPanel(ctrl: ctrl),
            'Objective-C' => _ObjcSettingsPanel(ctrl: ctrl),
            'Python' => _PythonSettingsPanel(ctrl: ctrl),
            'Go' => _GoSettingsPanel(ctrl: ctrl),
            'Rust' => _RustSettingsPanel(ctrl: ctrl),
            'Ruby' => _RubySettingsPanel(ctrl: ctrl),
            'PHP' => _PhpSettingsPanel(ctrl: ctrl),
            'Elixir' => _ElixirSettingsPanel(ctrl: ctrl),
            'C++' => _CppSettingsPanel(ctrl: ctrl),
            _ => const SizedBox.shrink(),
          };
        }),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TextStyle(color: AppColors.textD.withValues(alpha: 0.6)),
          ),
        ),
      ],
    );
  }
}

// ── Settings panels ───────────────────────────────────────────────────────────

class _DartSettingsPanel extends StatelessWidget {
  const _DartSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            tabs: const [Tab(text: 'Language'), Tab(text: 'Other')],
            labelStyle: TextStyle(
              fontSize: AppTextSize.body,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: TextStyle(fontSize: AppTextSize.body),
            labelColor: AppColors.secondaryD,
            unselectedLabelColor: AppColors.textD.withValues(alpha: 0.5),
            indicatorColor: AppColors.secondaryD,
            indicatorSize: TabBarIndicatorSize.label,
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
              children: [
                _DartLanguageTab(ctrl: ctrl),
                _DartOtherTab(ctrl: ctrl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DartLanguageTab extends StatelessWidget {
  const _DartLanguageTab({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.dartSettings.value;
      return SingleChildScrollView(
        padding: const EdgeInsets.only(top: AppSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleRow(
              label: 'Null safety',
              description: 'Use nullable types (String?, int?)',
              value: s.nullSafety,
              onChanged:
                  (v) =>
                      ctrl.updateDartSettings(s.copyWithValues(nullSafety: v)),
            ),
            _ToggleRow(
              label: 'Types only',
              description: 'Only generate fields, skip constructors & methods',
              value: s.typesOnly,
              onChanged:
                  (v) =>
                      ctrl.updateDartSettings(s.copyWithValues(typesOnly: v)),
            ),
            _ToggleRow(
              label: 'Make all properties required',
              description: 'Treat all fields as non-nullable',
              value: s.allRequired,
              onChanged:
                  (v) => ctrl.updateDartSettings(
                    s.copyWithValues(
                      allRequired: v,
                      allOptional: v ? false : null,
                    ),
                  ),
            ),
            _ToggleRow(
              label: 'Make all properties optional',
              description: 'Treat all fields as nullable',
              value: s.allOptional,
              onChanged:
                  (v) => ctrl.updateDartSettings(
                    s.copyWithValues(
                      allOptional: v,
                      allRequired: v ? false : null,
                    ),
                  ),
            ),
            _ToggleRow(
              label: 'Make all properties final',
              description: 'Use final instead of var',
              value: s.immutable,
              onChanged:
                  (v) =>
                      ctrl.updateDartSettings(s.copyWithValues(immutable: v)),
            ),
            _ToggleRow(
              label: 'Generate copyWith method',
              description: 'Add copyWith to each class',
              value: s.copyWith,
              onChanged:
                  (v) => ctrl.updateDartSettings(s.copyWithValues(copyWith: v)),
            ),
            _ToggleRow(
              label: 'Equatable',
              description: 'Extend Equatable and generate props',
              value: s.equatable,
              onChanged:
                  (v) =>
                      ctrl.updateDartSettings(s.copyWithValues(equatable: v)),
            ),
          ],
        ),
      );
    });
  }
}

class _DartOtherTab extends StatelessWidget {
  const _DartOtherTab({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.dartSettings.value;
      return SingleChildScrollView(
        padding: const EdgeInsets.only(top: AppSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TextInputRow(
              label: 'Part directive name',
              hint: 'e.g. user_model',
              value: s.partDirective,
              onChanged:
                  (v) => ctrl.updateDartSettings(
                    s.copyWithValues(partDirective: v),
                  ),
            ),
            _ToggleRow(
              label: 'Use fromMap() & toMap()',
              description: 'Use fromMap/toMap instead of fromJson/toJson',
              value: s.useMapNames,
              onChanged:
                  (v) =>
                      ctrl.updateDartSettings(s.copyWithValues(useMapNames: v)),
            ),
            _ToggleRow(
              label: '@freezed compatibility',
              description:
                  'Generate classes compatible with the freezed package',
              value: s.freezed,
              onChanged:
                  (v) => ctrl.updateDartSettings(
                    s.copyWithValues(
                      freezed: v,
                      jsonSerializable: v ? false : null,
                      hiveAdapters: v ? false : null,
                    ),
                  ),
            ),
            _ToggleRow(
              label: '@json_serializable annotations',
              description:
                  'Use @JsonSerializable() and generated _\$Class helpers',
              value: s.jsonSerializable,
              onChanged:
                  (v) => ctrl.updateDartSettings(
                    s.copyWithValues(
                      jsonSerializable: v,
                      freezed: v ? false : null,
                      hiveAdapters: v ? false : null,
                    ),
                  ),
            ),
            _ToggleRow(
              label: 'Hive type adapters',
              description: 'Add @HiveType and @HiveField annotations',
              value: s.hiveAdapters,
              onChanged:
                  (v) => ctrl.updateDartSettings(
                    s.copyWithValues(
                      hiveAdapters: v,
                      freezed: v ? false : null,
                      jsonSerializable: v ? false : null,
                    ),
                  ),
            ),
          ],
        ),
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
            onChanged:
                (v) => ctrl.updateTsSettings(s.copyWithValues(useType: v)),
          ),
          _ToggleRow(
            label: 'Readonly properties',
            description: 'Add readonly modifier to all fields',
            value: s.readonly,
            onChanged:
                (v) => ctrl.updateTsSettings(s.copyWithValues(readonly: v)),
          ),
          _ToggleRow(
            label: 'undefined instead of null',
            description: 'Use T | undefined instead of T | null',
            value: s.undefinedForNull,
            onChanged:
                (v) => ctrl.updateTsSettings(
                  s.copyWithValues(undefinedForNull: v),
                ),
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
            onChanged:
                (v) => ctrl.updateKotlinSettings(
                  s.copyWithValues(serialization: v),
                ),
          ),
          _ToggleRow(
            label: 'Mutable fields',
            description: 'Use var instead of val',
            value: s.mutable,
            onChanged:
                (v) => ctrl.updateKotlinSettings(s.copyWithValues(mutable: v)),
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
            onChanged:
                (v) => ctrl.updateSwiftSettings(s.copyWithValues(useClass: v)),
          ),
          _RadioGroupRow<String>(
            label: 'Access modifier',
            options: const ['internal', 'public'],
            labels: const ['internal (default)', 'public'],
            value: s.accessLevel,
            onChanged:
                (v) =>
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
            onChanged:
                (v) => ctrl.updatePythonSettings(s.copyWithValues(style: v)),
          ),
          _ToggleRow(
            label: 'Modern union syntax',
            description: 'Use X | None (Python 3.10+) instead of Optional[X]',
            value: s.modernUnion,
            onChanged:
                (v) =>
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
            onChanged:
                (v) => ctrl.updateGoSettings(s.copyWithValues(packageName: v)),
          ),
          _ToggleRow(
            label: 'omitempty',
            description: 'Add omitempty to json struct tags',
            value: s.omitempty,
            onChanged:
                (v) => ctrl.updateGoSettings(s.copyWithValues(omitempty: v)),
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
                    horizontal: AppSpacing.s,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? AppColors.secondaryD.withValues(alpha: 0.15)
                            : AppColors.textD.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color:
                          selected
                              ? AppColors.secondaryD.withValues(alpha: 0.45)
                              : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: AppTextSize.small,
                      color:
                          selected
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
    this.hint,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;

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
            child: CustomTextField(
              controller: _ctrl,
              hintText: widget.hint,
              textSize: AppTextSize.small,
              onChanged: widget.onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _JavaScriptSettingsPanel extends StatelessWidget {
  const _JavaScriptSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.jsSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            label: 'ES Modules',
            description: 'Use import/export instead of require/module.exports',
            value: s.useESModules,
            onChanged:
                (v) => ctrl.updateJsSettings(s.copyWithValues(useESModules: v)),
          ),
          _ToggleRow(
            label: 'JSDoc type annotations',
            description: 'Add /** @type {X} */ comments to fields',
            value: s.jsdoc,
            onChanged: (v) => ctrl.updateJsSettings(s.copyWithValues(jsdoc: v)),
          ),
        ],
      );
    });
  }
}

class _JavaSettingsPanel extends StatelessWidget {
  const _JavaSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.javaSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadioGroupRow<String>(
            label: 'Serialization',
            options: const ['jackson', 'gson', 'none'],
            labels: const ['Jackson', 'Gson', 'None'],
            value: s.serialization,
            onChanged:
                (v) =>
                    ctrl.updateJavaSettings(s.copyWithValues(serialization: v)),
          ),
          _ToggleRow(
            label: 'Lombok',
            description: 'Use @Data annotation instead of getters/setters',
            value: s.lombok,
            onChanged:
                (v) => ctrl.updateJavaSettings(s.copyWithValues(lombok: v)),
          ),
        ],
      );
    });
  }
}

class _ObjcSettingsPanel extends StatelessWidget {
  const _ObjcSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.objcSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            label: 'NS_ASSUME_NONNULL_BEGIN',
            description: 'Wrap interface with nonnull macros',
            value: s.useNonnull,
            onChanged:
                (v) => ctrl.updateObjcSettings(s.copyWithValues(useNonnull: v)),
          ),
        ],
      );
    });
  }
}

class _RustSettingsPanel extends StatelessWidget {
  const _RustSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.rustSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            label: 'Serde (Serialize / Deserialize)',
            description: 'Add serde derive macros and import',
            value: s.serde,
            onChanged:
                (v) => ctrl.updateRustSettings(s.copyWithValues(serde: v)),
          ),
          _ToggleRow(
            label: '#[derive(Debug)]',
            description: 'Add Debug derive',
            value: s.deriveDebug,
            onChanged:
                (v) =>
                    ctrl.updateRustSettings(s.copyWithValues(deriveDebug: v)),
          ),
          _ToggleRow(
            label: '#[derive(Clone)]',
            description: 'Add Clone derive',
            value: s.deriveClone,
            onChanged:
                (v) =>
                    ctrl.updateRustSettings(s.copyWithValues(deriveClone: v)),
          ),
          _ToggleRow(
            label: '#[derive(PartialEq)]',
            description: 'Add PartialEq derive',
            value: s.derivePartialEq,
            onChanged:
                (v) => ctrl.updateRustSettings(
                  s.copyWithValues(derivePartialEq: v),
                ),
          ),
        ],
      );
    });
  }
}

class _RubySettingsPanel extends StatelessWidget {
  const _RubySettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.rubySettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            label: 'attr_accessor',
            description:
                'Use attr_accessor (read/write) instead of attr_reader',
            value: s.attrAccessor,
            onChanged:
                (v) =>
                    ctrl.updateRubySettings(s.copyWithValues(attrAccessor: v)),
          ),
          _ToggleRow(
            label: '# frozen_string_literal: true',
            description: 'Add frozen string literal magic comment',
            value: s.frozen,
            onChanged:
                (v) => ctrl.updateRubySettings(s.copyWithValues(frozen: v)),
          ),
        ],
      );
    });
  }
}

class _PhpSettingsPanel extends StatelessWidget {
  const _PhpSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.phpSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadioGroupRow<String>(
            label: 'PHP version',
            options: const ['8', '7'],
            labels: const ['PHP 8 (constructor promotion)', 'PHP 7 (classic)'],
            value: s.phpVersion,
            onChanged:
                (v) => ctrl.updatePhpSettings(s.copyWithValues(phpVersion: v)),
          ),
          _ToggleRow(
            label: 'declare(strict_types=1)',
            description: 'Enable strict type checking',
            value: s.strictTypes,
            onChanged:
                (v) => ctrl.updatePhpSettings(s.copyWithValues(strictTypes: v)),
          ),
        ],
      );
    });
  }
}

class _ElixirSettingsPanel extends StatelessWidget {
  const _ElixirSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.elixirSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleRow(
            label: '@enforce_keys',
            description: 'Add @enforce_keys for required fields',
            value: s.enforceKeys,
            onChanged:
                (v) =>
                    ctrl.updateElixirSettings(s.copyWithValues(enforceKeys: v)),
          ),
          _ToggleRow(
            label: '@type spec',
            description: 'Generate @type and @spec annotations',
            value: s.typeSpec,
            onChanged:
                (v) => ctrl.updateElixirSettings(s.copyWithValues(typeSpec: v)),
          ),
        ],
      );
    });
  }
}

class _CppSettingsPanel extends StatelessWidget {
  const _CppSettingsPanel({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final s = ctrl.cppSettings.value;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadioGroupRow<String>(
            label: 'JSON library',
            options: const ['nlohmann', 'none'],
            labels: const ['nlohmann/json', 'Struct only (no JSON)'],
            value: s.jsonLib,
            onChanged:
                (v) => ctrl.updateCppSettings(s.copyWithValues(jsonLib: v)),
          ),
          _ToggleRow(
            label: 'std::optional for nullable',
            description: 'Use std::optional<T> instead of T*',
            value: s.useOptional,
            onChanged:
                (v) => ctrl.updateCppSettings(s.copyWithValues(useOptional: v)),
          ),
        ],
      );
    });
  }
}

// ── Root class name field ─────────────────────────────────────────────────────

class _NameField extends StatefulWidget {
  const _NameField({required this.ctrl});
  final JsonToCodeController ctrl;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.ctrl.rootName.value);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.m,
        AppSpacing.xs,
        AppSpacing.m,
        AppSpacing.s,
      ),
      child: Row(
        children: [
          Text(
            'Name',
            style: TextStyle(
              color: AppColors.textD.withValues(alpha: 0.45),
              fontSize: AppTextSize.small,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Expanded(
            child: SizedBox(
              height: 28,
              child: CustomTextField(
                controller: _textCtrl,
                hintText: 'Root',
                textSize: AppTextSize.small,
                onChanged: (v) {
                  widget.ctrl.rootName.value = v;
                  widget.ctrl.generate();
                },
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
              indicatorBuilder:
                  (_, editing, chunk, notifier) => Row(
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
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color:
                selected
                    ? AppColors.secondaryD.withValues(alpha: 0.15)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color:
                  selected
                      ? AppColors.secondaryD.withValues(alpha: 0.45)
                      : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: AppTextSize.small,
              color:
                  selected
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
              indicatorBuilder:
                  (_, editing, chunk, notifier) => Row(
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
