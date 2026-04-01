import 'dart:convert';

import 'package:get/get.dart';
import 'package:mockondo/features/json_to_code/core/generators.dart';
import 'package:mockondo/features/json_to_code/core/json_schema.dart';
import 'package:mockondo/features/json_to_code/core/lang_settings.dart';
import 'package:re_editor/re_editor.dart';

class JsonToCodeController extends GetxController {
  final inputCtrl = CodeLineEditingController();
  final outputCtrl = CodeLineEditingController();

  final selectedLanguage = 'Dart'.obs;
  final rootName = 'Root'.obs;
  final errorMessage = RxnString();

  // Per-language settings (observable so UI rebuilds)
  final dartSettings = DartSettings().obs;
  final tsSettings = TypeScriptSettings().obs;
  final jsSettings = JavaScriptSettings().obs;
  final kotlinSettings = KotlinSettings().obs;
  final javaSettings = JavaSettings().obs;
  final swiftSettings = SwiftSettings().obs;
  final objcSettings = ObjcSettings().obs;
  final pythonSettings = PythonSettings().obs;
  final goSettings = GoSettings().obs;
  final rustSettings = RustSettings().obs;
  final rubySettings = RubySettings().obs;
  final phpSettings = PhpSettings().obs;
  final elixirSettings = ElixirSettings().obs;
  final cppSettings = CppSettings().obs;

  static const languages = [
    'Dart',
    'TypeScript',
    'JavaScript',
    'Kotlin',
    'Java',
    'Swift',
    'Objective-C',
    'Python',
    'Go',
    'Rust',
    'Ruby',
    'PHP',
    'Elixir',
    'C++',
  ];

  @override
  void onClose() {
    inputCtrl.dispose();
    outputCtrl.dispose();
    super.onClose();
  }

  void selectLanguage(String lang) {
    selectedLanguage.value = lang;
    generate();
  }

  void updateDartSettings(DartSettings s) { dartSettings.value = s; generate(); }
  void updateTsSettings(TypeScriptSettings s) { tsSettings.value = s; generate(); }
  void updateJsSettings(JavaScriptSettings s) { jsSettings.value = s; generate(); }
  void updateKotlinSettings(KotlinSettings s) { kotlinSettings.value = s; generate(); }
  void updateJavaSettings(JavaSettings s) { javaSettings.value = s; generate(); }
  void updateSwiftSettings(SwiftSettings s) { swiftSettings.value = s; generate(); }
  void updateObjcSettings(ObjcSettings s) { objcSettings.value = s; generate(); }
  void updatePythonSettings(PythonSettings s) { pythonSettings.value = s; generate(); }
  void updateGoSettings(GoSettings s) { goSettings.value = s; generate(); }
  void updateRustSettings(RustSettings s) { rustSettings.value = s; generate(); }
  void updateRubySettings(RubySettings s) { rubySettings.value = s; generate(); }
  void updatePhpSettings(PhpSettings s) { phpSettings.value = s; generate(); }
  void updateElixirSettings(ElixirSettings s) { elixirSettings.value = s; generate(); }
  void updateCppSettings(CppSettings s) { cppSettings.value = s; generate(); }

  void generate() {
    final text = inputCtrl.text.trim();
    if (text.isEmpty) {
      outputCtrl.text = '';
      errorMessage.value = null;
      return;
    }

    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (e) {
      errorMessage.value = 'Invalid JSON: $e';
      return;
    }

    if (parsed is List) {
      if (parsed.isEmpty) {
        errorMessage.value = 'Array is empty — cannot infer types.';
        return;
      }
      parsed = parsed.first;
    }

    if (parsed is! Map) {
      errorMessage.value = 'Root must be a JSON object { } or array [ { } ].';
      return;
    }

    final name = rootName.value.trim().isEmpty ? 'Root' : rootName.value.trim();
    final root = inferType(parsed, name);
    if (root is! JObject) {
      errorMessage.value = 'Unexpected type inference result.';
      return;
    }

    try {
      outputCtrl.text = _generate(selectedLanguage.value, root);
      errorMessage.value = null;
    } catch (e) {
      errorMessage.value = 'Generation failed: $e';
    }
  }

  String _generate(String lang, JObject root) => switch (lang) {
        'Dart' => DartGenerator(settings: dartSettings.value).generate(root),
        'TypeScript' => TypeScriptGenerator(settings: tsSettings.value).generate(root),
        'JavaScript' => JavaScriptGenerator(settings: jsSettings.value).generate(root),
        'Kotlin' => KotlinGenerator(settings: kotlinSettings.value).generate(root),
        'Java' => JavaGenerator(settings: javaSettings.value).generate(root),
        'Swift' => SwiftGenerator(settings: swiftSettings.value).generate(root),
        'Objective-C' => ObjcGenerator(settings: objcSettings.value).generate(root),
        'Python' => PythonGenerator(settings: pythonSettings.value).generate(root),
        'Go' => GoGenerator(settings: goSettings.value).generate(root),
        'Rust' => RustGenerator(settings: rustSettings.value).generate(root),
        'Ruby' => RubyGenerator(settings: rubySettings.value).generate(root),
        'PHP' => PhpGenerator(settings: phpSettings.value).generate(root),
        'Elixir' => ElixirGenerator(settings: elixirSettings.value).generate(root),
        'C++' => CppGenerator(settings: cppSettings.value).generate(root),
        _ => '',
      };
}
