import 'package:mockondo/features/json_to_code/core/json_schema.dart';
import 'package:mockondo/features/json_to_code/core/lang_settings.dart';

// ── Abstract base ────────────────────────────────────────────────────────────

abstract class CodeGenerator {
  String generate(JObject root);
}

// ── Dart ─────────────────────────────────────────────────────────────────────

class DartGenerator extends CodeGenerator {
  final DartSettings settings;

  DartGenerator({DartSettings? settings})
      : settings = settings ?? DartSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();

    // Imports
    if (settings.freezed) {
      buf.writeln(
          "import 'package:freezed_annotation/freezed_annotation.dart';");
    } else if (settings.jsonSerializable) {
      buf.writeln("import 'package:json_annotation/json_annotation.dart';");
    } else if (settings.hiveAdapters) {
      buf.writeln("import 'package:hive/hive.dart';");
    } else if (settings.equatable) {
      buf.writeln("import 'package:equatable/equatable.dart';");
    }

    // Part directives for code-gen packages
    if (settings.freezed || settings.jsonSerializable || settings.hiveAdapters) {
      final partName = settings.partDirective.isNotEmpty
          ? settings.partDirective
          : root.className.toLowerCase();
      if (settings.freezed) {
        buf.writeln("part '$partName.freezed.dart';");
        buf.writeln("part '$partName.g.dart';");
      } else {
        buf.writeln("part '$partName.g.dart';");
      }
    }

    if (buf.isNotEmpty) buf.writeln();

    final classList = classes.reversed.toList();
    for (var i = 0; i < classList.length; i++) {
      _writeClass(buf, classList[i], i);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  /// Returns the effective JType for a field after applying allRequired/allOptional/nullSafety.
  JType _fieldType(JType t) {
    if (settings.allOptional && t is! JNullable) return JNullable(t);
    if (settings.allRequired && t is JNullable) return t.inner;
    if (!settings.nullSafety && t is JNullable) return t.inner;
    return t;
  }

  void _writeClass(StringBuffer buf, JObject obj, int typeIndex) {
    // Delegate for @freezed
    if (settings.freezed) {
      _writeFreezedClass(buf, obj);
      return;
    }

    final fieldMod = settings.immutable ? 'final ' : '';

    // Class-level annotations
    if (settings.jsonSerializable) buf.writeln('@JsonSerializable()');
    if (settings.hiveAdapters) buf.writeln('@HiveType(typeId: $typeIndex)');
    if (settings.equatable && !settings.hiveAdapters) {
      // no annotation needed, just mixin via extends
    }

    final extendsClause = settings.hiveAdapters
        ? ' extends HiveObject'
        : settings.equatable
            ? ' extends Equatable'
            : '';

    buf.writeln('class ${obj.className}$extendsClause {');

    // Fields
    final entries = obj.fields.entries.toList();
    for (var i = 0; i < entries.length; i++) {
      final key = entries[i].key;
      final t = _fieldType(entries[i].value);
      if (settings.hiveAdapters) buf.writeln('  @HiveField($i)');
      buf.writeln('  $fieldMod${_type(t)} ${toCamelCase(key)};');
    }

    if (settings.typesOnly) {
      buf.writeln('}');
      return;
    }

    buf.writeln();

    // Constructor
    buf.writeln('  ${obj.className}({');
    for (final e in entries) {
      final t = _fieldType(e.value);
      final req = t is JNullable ? '' : 'required ';
      buf.writeln('    ${req}this.${toCamelCase(e.key)},');
    }
    buf.writeln('  });');

    if (settings.hiveAdapters) {
      // Hive uses generated adapters — no fromJson/toJson needed
      buf.writeln('}');
      return;
    }

    buf.writeln();

    final fromName = settings.useMapNames ? 'fromMap' : 'fromJson';
    final toName = settings.useMapNames ? 'toMap' : 'toJson';

    // fromJson / fromMap
    if (settings.jsonSerializable) {
      buf.writeln(
          '  factory ${obj.className}.$fromName(Map<String, dynamic> json) =>');
      buf.writeln('      _\$${obj.className}FromJson(json);');
    } else {
      buf.writeln(
          '  factory ${obj.className}.$fromName(Map<String, dynamic> json) =>');
      buf.writeln('      ${obj.className}(');
      for (final e in entries) {
        final camel = toCamelCase(e.key);
        final t = _fieldType(e.value);
        buf.writeln(
            "        $camel: ${_fromJson(t, "json['${e.key}']")},");
      }
      buf.writeln('      );');
    }

    buf.writeln();

    // toJson / toMap
    if (settings.jsonSerializable) {
      buf.writeln(
          '  Map<String, dynamic> $toName() => _\$${obj.className}ToJson(this);');
    } else {
      buf.writeln('  Map<String, dynamic> $toName() => {');
      for (final e in entries) {
        final camel = toCamelCase(e.key);
        final t = _fieldType(e.value);
        buf.writeln("    '${e.key}': ${_toJson(t, camel)},");
      }
      buf.writeln('  };');
    }

    // copyWith
    if (settings.copyWith) {
      buf.writeln();
      buf.writeln('  ${obj.className} copyWith({');
      for (final e in entries) {
        final t = _fieldType(e.value);
        buf.writeln('    ${_type(t)}? ${toCamelCase(e.key)},');
      }
      buf.writeln('  }) =>');
      buf.writeln('      ${obj.className}(');
      for (final e in entries) {
        final camel = toCamelCase(e.key);
        buf.writeln('        $camel: $camel ?? this.$camel,');
      }
      buf.writeln('      );');
    }

    // Equatable props
    if (settings.equatable) {
      buf.writeln();
      final props = obj.fields.keys.map(toCamelCase).join(', ');
      buf.writeln('  @override');
      buf.writeln('  List<Object?> get props => [$props];');
    }

    buf.writeln('}');
  }

  void _writeFreezedClass(StringBuffer buf, JObject obj) {
    buf.writeln('@freezed');
    buf.writeln('class ${obj.className} with _\$${obj.className} {');
    buf.writeln('  const factory ${obj.className}({');
    for (final e in obj.fields.entries) {
      final t = _fieldType(e.value);
      final req = t is JNullable ? '' : 'required ';
      buf.writeln('    $req${_type(t)} ${toCamelCase(e.key)},');
    }
    buf.writeln('  }) = _${obj.className};');
    buf.writeln();
    buf.writeln(
        '  factory ${obj.className}.fromJson(Map<String, dynamic> json)');
    buf.writeln('      => _\$${obj.className}FromJson(json);');
    buf.writeln('}');
  }

  String _type(JType t) {
    if (!settings.nullSafety) {
      // collapse nullables when null safety is off
      if (t is JNullable) return _type(t.inner);
    }
    if (t is JPrimitive) return t.name;
    if (t is JNullable) return '${_type(t.inner)}?';
    if (t is JArray) return 'List<${_type(t.item)}>';
    if (t is JObject) return t.className;
    return 'dynamic';
  }

  String _fromJson(JType t, String expr) {
    if (t is JNullable) {
      final inner = t.inner;
      if (inner is JPrimitive) {
        if (inner.name == 'dynamic') return expr;
        return settings.nullSafety
            ? '$expr as ${inner.name}?'
            : '$expr as ${inner.name}';
      }
      if (inner is JObject) {
        return settings.nullSafety
            ? '$expr == null ? null : ${inner.className}.fromJson($expr as Map<String, dynamic>)'
            : '${inner.className}.fromJson($expr as Map<String, dynamic>)';
      }
      return expr;
    }
    if (t is JPrimitive) {
      if (t.name == 'dynamic') return expr;
      return '$expr as ${t.name}';
    }
    if (t is JArray) {
      final item = t.item;
      if (item is JPrimitive && item.name != 'dynamic') {
        return '($expr as List<dynamic>).cast<${item.name}>()';
      }
      if (item is JObject) {
        return '($expr as List<dynamic>)'
            '.map((e) => ${item.className}.fromJson(e as Map<String, dynamic>))'
            '.toList()';
      }
      return '$expr as List<dynamic>';
    }
    if (t is JObject) {
      return '${t.className}.fromJson($expr as Map<String, dynamic>)';
    }
    return expr;
  }

  String _toJson(JType t, String expr) {
    if (t is JNullable) return _toJson(t.inner, expr);
    if (t is JObject) return '$expr.toJson()';
    if (t is JArray && t.item is JObject) {
      return '$expr.map((e) => e.toJson()).toList()';
    }
    return expr;
  }
}

// ── TypeScript ───────────────────────────────────────────────────────────────

class TypeScriptGenerator extends CodeGenerator {
  final TypeScriptSettings settings;

  TypeScriptGenerator({TypeScriptSettings? settings})
      : settings = settings ?? TypeScriptSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    for (final cls in classes.reversed) {
      _write(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _write(StringBuffer buf, JObject obj) {
    if (settings.useType) {
      buf.writeln('export type ${obj.className} = {');
      for (final e in obj.fields.entries) {
        final optional = e.value is JNullable ? '?' : '';
        final ro = settings.readonly ? 'readonly ' : '';
        buf.writeln('  $ro${e.key}$optional: ${_type(e.value)};');
      }
      buf.writeln('};');
    } else {
      buf.writeln('export interface ${obj.className} {');
      for (final e in obj.fields.entries) {
        final optional = e.value is JNullable ? '?' : '';
        final ro = settings.readonly ? 'readonly ' : '';
        buf.writeln('  $ro${e.key}$optional: ${_type(e.value)};');
      }
      buf.writeln('}');
    }
  }

  String _type(JType t) {
    final nullToken = settings.undefinedForNull ? 'undefined' : 'null';
    if (t is JNullable) return '${_type(t.inner)} | $nullToken';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'string',
        'int' || 'double' => 'number',
        'bool' => 'boolean',
        _ => 'any',
      };
    }
    if (t is JArray) return '${_type(t.item)}[]';
    if (t is JObject) return t.className;
    return 'any';
  }
}

// ── Kotlin ───────────────────────────────────────────────────────────────────

class KotlinGenerator extends CodeGenerator {
  final KotlinSettings settings;

  KotlinGenerator({KotlinSettings? settings})
      : settings = settings ?? KotlinSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    switch (settings.serialization) {
      case 'gson':
        buf.writeln(
            'import com.google.gson.annotations.SerializedName');
      case 'moshi':
        buf.writeln('import com.squareup.moshi.Json');
        buf.writeln('import com.squareup.moshi.JsonClass');
      case 'kotlinx':
        buf.writeln(
            'import kotlinx.serialization.SerialName');
        buf.writeln('import kotlinx.serialization.Serializable');
    }
    buf.writeln();
    for (final cls in classes.reversed) {
      _writeDataClass(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeDataClass(StringBuffer buf, JObject obj) {
    if (settings.serialization == 'moshi') {
      buf.writeln('@JsonClass(generateAdapter = true)');
    } else if (settings.serialization == 'kotlinx') {
      buf.writeln('@Serializable');
    }
    buf.writeln('data class ${obj.className}(');
    final entries = obj.fields.entries.toList();
    final varMod = settings.mutable ? 'var' : 'val';
    for (var i = 0; i < entries.length; i++) {
      final key = entries[i].key;
      final type = entries[i].value;
      final comma = i < entries.length - 1 ? ',' : '';
      final annotation = switch (settings.serialization) {
        'gson' => '    @SerializedName("$key")',
        'moshi' => '    @Json(name = "$key")',
        'kotlinx' => '    @SerialName("$key")',
        _ => '',
      };
      buf.writeln(annotation);
      buf.writeln(
          '    $varMod ${toCamelCase(key)}: ${_type(type)}$comma');
    }
    buf.writeln(')');
  }

  String _type(JType t) {
    if (t is JNullable) return '${_type(t.inner)}?';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'String',
        'int' => 'Int',
        'double' => 'Double',
        'bool' => 'Boolean',
        _ => 'Any',
      };
    }
    if (t is JArray) return 'List<${_type(t.item)}>';
    if (t is JObject) return t.className;
    return 'Any';
  }
}

// ── Swift ────────────────────────────────────────────────────────────────────

class SwiftGenerator extends CodeGenerator {
  final SwiftSettings settings;

  SwiftGenerator({SwiftSettings? settings})
      : settings = settings ?? SwiftSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    for (final cls in classes.reversed) {
      _writeType(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeType(StringBuffer buf, JObject obj) {
    final keyword = settings.useClass ? 'class' : 'struct';
    final access =
        settings.accessLevel == 'public' ? 'public ' : '';
    buf.writeln('$access$keyword ${obj.className}: Codable {');
    for (final e in obj.fields.entries) {
      buf.writeln(
          '    ${access}let ${toCamelCase(e.key)}: ${_type(e.value)}');
    }
    final needsKeys =
        obj.fields.keys.any((k) => k != toCamelCase(k));
    if (needsKeys) {
      buf.writeln();
      buf.writeln(
          '    ${access}enum CodingKeys: String, CodingKey {');
      for (final k in obj.fields.keys) {
        buf.writeln('        case ${toCamelCase(k)} = "$k"');
      }
      buf.writeln('    }');
    }
    buf.writeln('}');
  }

  String _type(JType t) {
    if (t is JNullable) return '${_type(t.inner)}?';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'String',
        'int' => 'Int',
        'double' => 'Double',
        'bool' => 'Bool',
        _ => 'Any',
      };
    }
    if (t is JArray) return '[${_type(t.item)}]';
    if (t is JObject) return t.className;
    return 'Any';
  }
}

// ── Python ───────────────────────────────────────────────────────────────────

class PythonGenerator extends CodeGenerator {
  final PythonSettings settings;

  PythonGenerator({PythonSettings? settings})
      : settings = settings ?? PythonSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();

    switch (settings.style) {
      case 'dataclass':
        buf.writeln('from __future__ import annotations');
        buf.writeln('from dataclasses import dataclass');
        if (!settings.modernUnion) {
          buf.writeln('from typing import List, Any, Optional');
        } else {
          buf.writeln('from typing import List, Any');
        }
      case 'typeddict':
        buf.writeln('from __future__ import annotations');
        buf.writeln('from typing import TypedDict, List, Any');
        if (!settings.modernUnion) {
          buf.writeln('from typing import Optional');
        }
      case 'attrs':
        buf.writeln('from __future__ import annotations');
        buf.writeln('import attrs');
        if (!settings.modernUnion) {
          buf.writeln('from typing import List, Any, Optional');
        } else {
          buf.writeln('from typing import List, Any');
        }
    }
    buf.writeln();

    for (final cls in classes.reversed) {
      _writeClass(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeClass(StringBuffer buf, JObject obj) {
    switch (settings.style) {
      case 'dataclass':
        buf.writeln('@dataclass');
        buf.writeln('class ${obj.className}:');
        if (obj.fields.isEmpty) {
          buf.writeln('    pass');
        } else {
          for (final e in obj.fields.entries) {
            buf.writeln('    ${e.key}: ${_type(e.value)}');
          }
        }
      case 'typeddict':
        buf.writeln('class ${obj.className}(TypedDict):');
        if (obj.fields.isEmpty) {
          buf.writeln('    pass');
        } else {
          for (final e in obj.fields.entries) {
            buf.writeln('    ${e.key}: ${_type(e.value)}');
          }
        }
      case 'attrs':
        buf.writeln('@attrs.define');
        buf.writeln('class ${obj.className}:');
        if (obj.fields.isEmpty) {
          buf.writeln('    pass');
        } else {
          for (final e in obj.fields.entries) {
            buf.writeln('    ${e.key}: ${_type(e.value)}');
          }
        }
    }
  }

  String _type(JType t) {
    if (t is JNullable) {
      return settings.modernUnion
          ? '${_type(t.inner)} | None'
          : 'Optional[${_type(t.inner)}]';
    }
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'str',
        'int' => 'int',
        'double' => 'float',
        'bool' => 'bool',
        _ => 'Any',
      };
    }
    if (t is JArray) return 'List[${_type(t.item)}]';
    if (t is JObject) return t.className;
    return 'Any';
  }
}

// ── Go ───────────────────────────────────────────────────────────────────────

class GoGenerator extends CodeGenerator {
  final GoSettings settings;

  GoGenerator({GoSettings? settings})
      : settings = settings ?? GoSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    buf.writeln('package ${settings.packageName}');
    buf.writeln();
    for (final cls in classes.reversed) {
      _writeStruct(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeStruct(StringBuffer buf, JObject obj) {
    buf.writeln('type ${obj.className} struct {');
    for (final e in obj.fields.entries) {
      final goName = toPascalCase(e.key);
      final tag = settings.omitempty
          ? '`json:"${e.key},omitempty"`'
          : '`json:"${e.key}"`';
      buf.writeln('    $goName ${_type(e.value)} $tag');
    }
    buf.writeln('}');
  }

  String _type(JType t) {
    if (t is JNullable) return '*${_type(t.inner)}';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'string',
        'int' => 'int64',
        'double' => 'float64',
        'bool' => 'bool',
        _ => 'interface{}',
      };
    }
    if (t is JArray) return '[]${_type(t.item)}';
    if (t is JObject) return t.className;
    return 'interface{}';
  }
}

// ── JavaScript ────────────────────────────────────────────────────────────────

class JavaScriptGenerator extends CodeGenerator {
  final JavaScriptSettings settings;

  JavaScriptGenerator({JavaScriptSettings? settings})
      : settings = settings ?? JavaScriptSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    for (final cls in classes.reversed) {
      _writeClass(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeClass(StringBuffer buf, JObject obj) {
    final export = settings.useESModules ? 'export ' : '';
    buf.writeln('${export}class ${obj.className} {');

    if (settings.jsdoc) {
      for (final e in obj.fields.entries) {
        buf.writeln('  /** @type {${_type(e.value)}} */');
        buf.writeln('  ${toCamelCase(e.key)};');
      }
    } else {
      for (final e in obj.fields.entries) {
        buf.writeln('  ${toCamelCase(e.key)};');
      }
    }

    buf.writeln();

    // fromJSON
    if (settings.jsdoc) {
      buf.writeln('  /** @param {Record<string, any>} data @returns {${obj.className}} */');
    }
    buf.writeln('  static fromJSON(data) {');
    buf.writeln('    const obj = new ${obj.className}();');
    for (final e in obj.fields.entries) {
      final camel = toCamelCase(e.key);
      buf.writeln("    obj.$camel = ${_fromJSON(e.value, "data['${e.key}']")};");
    }
    buf.writeln('    return obj;');
    buf.writeln('  }');
    buf.writeln();

    // toJSON
    buf.writeln('  toJSON() {');
    buf.writeln('    return {');
    for (final e in obj.fields.entries) {
      final camel = toCamelCase(e.key);
      buf.writeln("      '${e.key}': ${_toJSON(e.value, camel)},");
    }
    buf.writeln('    };');
    buf.writeln('  }');
    buf.writeln('}');

    if (!settings.useESModules) {
      buf.writeln();
      buf.writeln('module.exports = { ${obj.className} };');
    }
  }

  String _type(JType t) {
    if (t is JNullable) return '${_type(t.inner)} | null';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'string',
        'int' || 'double' => 'number',
        'bool' => 'boolean',
        _ => 'any',
      };
    }
    if (t is JArray) return '${_type(t.item)}[]';
    if (t is JObject) return t.className;
    return 'any';
  }

  String _fromJSON(JType t, String expr) {
    if (t is JNullable) {
      final inner = t.inner;
      if (inner is JObject) {
        return '$expr != null ? ${inner.className}.fromJSON($expr) : null';
      }
      return '$expr ?? null';
    }
    if (t is JObject) return '${t.className}.fromJSON($expr)';
    if (t is JArray && t.item is JObject) {
      return '($expr ?? []).map((e) => ${(t.item as JObject).className}.fromJSON(e))';
    }
    return expr;
  }

  String _toJSON(JType t, String expr) {
    if (t is JNullable) return _toJSON(t.inner, expr);
    if (t is JObject) return '$expr?.toJSON()';
    if (t is JArray && t.item is JObject) {
      return '$expr?.map((e) => e.toJSON())';
    }
    return expr;
  }
}

// ── Rust ─────────────────────────────────────────────────────────────────────

class RustGenerator extends CodeGenerator {
  final RustSettings settings;

  RustGenerator({RustSettings? settings})
      : settings = settings ?? RustSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();

    if (settings.serde) {
      buf.writeln('use serde::{Deserialize, Serialize};');
      buf.writeln();
    }

    for (final cls in classes.reversed) {
      _writeStruct(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeStruct(StringBuffer buf, JObject obj) {
    final derives = <String>[];
    if (settings.deriveDebug) derives.add('Debug');
    if (settings.deriveClone) derives.add('Clone');
    if (settings.derivePartialEq) derives.add('PartialEq');
    if (settings.serde) {
      derives.add('Serialize');
      derives.add('Deserialize');
    }
    if (derives.isNotEmpty) {
      buf.writeln('#[derive(${derives.join(', ')})]');
    }
    buf.writeln('pub struct ${obj.className} {');
    for (final e in obj.fields.entries) {
      final rustName = _toSnakeCase(e.key);
      if (rustName != e.key && settings.serde) {
        buf.writeln('    #[serde(rename = "${e.key}")]');
      }
      if (e.value is JNullable && settings.serde) {
        buf.writeln(
            '    #[serde(skip_serializing_if = "Option::is_none")]');
      }
      buf.writeln('    pub $rustName: ${_type(e.value)},');
    }
    buf.writeln('}');
  }

  String _toSnakeCase(String s) {
    final result = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == c.toUpperCase() && c != c.toLowerCase() && i > 0) {
        result.write('_');
      }
      result.write(c.toLowerCase());
    }
    return result.toString().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
  }

  String _type(JType t) {
    if (t is JNullable) return 'Option<${_type(t.inner)}>';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'String',
        'int' => 'i64',
        'double' => 'f64',
        'bool' => 'bool',
        _ => 'serde_json::Value',
      };
    }
    if (t is JArray) return 'Vec<${_type(t.item)}>';
    if (t is JObject) return t.className;
    return 'serde_json::Value';
  }
}

// ── Ruby ─────────────────────────────────────────────────────────────────────

class RubyGenerator extends CodeGenerator {
  final RubySettings settings;

  RubyGenerator({RubySettings? settings})
      : settings = settings ?? RubySettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    if (settings.frozen) {
      buf.writeln('# frozen_string_literal: true');
      buf.writeln();
    }
    for (final cls in classes.reversed) {
      _writeClass(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeClass(StringBuffer buf, JObject obj) {
    buf.writeln('class ${obj.className}');
    final accessor = settings.attrAccessor ? 'attr_accessor' : 'attr_reader';
    final fields = obj.fields.keys.map(_toRubyName).join(', :');
    if (obj.fields.isNotEmpty) {
      buf.writeln('  $accessor :$fields');
      buf.writeln();
    }

    // initialize
    buf.writeln("  def initialize(data = {})");
    for (final e in obj.fields.entries) {
      final rubyName = _toRubyName(e.key);
      buf.writeln("    @$rubyName = ${_fromHash(e.value, "data['${e.key}']")}");
    }
    buf.writeln('  end');
    buf.writeln();

    // self.from_hash
    buf.writeln('  def self.from_hash(data)');
    buf.writeln('    new(data)');
    buf.writeln('  end');
    buf.writeln();

    // to_hash
    buf.writeln('  def to_hash');
    buf.writeln('    {');
    for (final e in obj.fields.entries) {
      final rubyName = _toRubyName(e.key);
      buf.writeln("      '${e.key}' => ${_toHash(e.value, "@$rubyName")},");
    }
    buf.writeln('    }.compact');
    buf.writeln('  end');
    buf.writeln('end');
  }

  String _toRubyName(String s) =>
      s.replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m.group(0)!.toLowerCase()}')
          .replaceAll(RegExp(r'^_'), '');

  String _fromHash(JType t, String expr) {
    if (t is JNullable) {
      final inner = t.inner;
      if (inner is JObject) return "${inner.className}.from_hash($expr) if $expr";
      return expr;
    }
    if (t is JObject) return '${t.className}.from_hash($expr)';
    if (t is JArray && t.item is JObject) {
      return '($expr || []).map { |e| ${(t.item as JObject).className}.from_hash(e) }';
    }
    return expr;
  }

  String _toHash(JType t, String expr) {
    if (t is JNullable) return _toHash(t.inner, expr);
    if (t is JObject) return '$expr&.to_hash';
    if (t is JArray && t.item is JObject) {
      return '$expr&.map(&:to_hash)';
    }
    return expr;
  }
}

// ── Elixir ───────────────────────────────────────────────────────────────────

class ElixirGenerator extends CodeGenerator {
  final ElixirSettings settings;

  ElixirGenerator({ElixirSettings? settings})
      : settings = settings ?? ElixirSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    for (final cls in classes.reversed) {
      _writeModule(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeModule(StringBuffer buf, JObject obj) {
    buf.writeln('defmodule ${obj.className} do');

    if (settings.enforceKeys) {
      final required = obj.fields.entries
          .where((e) => e.value is! JNullable)
          .map((e) => ':${_toAtom(e.key)}')
          .join(', ');
      if (required.isNotEmpty) {
        buf.writeln('  @enforce_keys [$required]');
      }
    }

    // defstruct
    final structFields = obj.fields.entries.map((e) {
      final atom = _toAtom(e.key);
      return e.value is JNullable ? ':$atom' : '$atom: nil';
    }).join(', ');
    buf.writeln('  defstruct [$structFields]');

    // @type
    if (settings.typeSpec) {
      buf.writeln();
      buf.writeln('  @type t :: %__MODULE__{');
      for (final e in obj.fields.entries) {
        buf.writeln('    ${_toAtom(e.key)}: ${_type(e.value)},');
      }
      buf.writeln('  }');
    }

    buf.writeln();

    // from_map
    if (settings.typeSpec) buf.writeln('  @spec from_map(map()) :: t()');
    buf.writeln('  def from_map(%{} = map) do');
    buf.writeln('    %__MODULE__{');
    for (final e in obj.fields.entries) {
      final atom = _toAtom(e.key);
      buf.writeln('      $atom: ${_fromMap(e.value, 'map["${e.key}"]')},');
    }
    buf.writeln('    }');
    buf.writeln('  end');
    buf.writeln();

    // to_map
    if (settings.typeSpec) buf.writeln('  @spec to_map(t()) :: map()');
    buf.writeln('  def to_map(%__MODULE__{} = s) do');
    buf.writeln('    %{');
    for (final e in obj.fields.entries) {
      final atom = _toAtom(e.key);
      buf.writeln('      "${e.key}" => ${_toMap(e.value, "s.$atom")},');
    }
    buf.writeln('    }');
    buf.writeln('  end');
    buf.writeln('end');
  }

  String _toAtom(String s) =>
      s.replaceAllMapped(RegExp(r'([A-Z])'), (m) => '_${m.group(0)!.toLowerCase()}')
          .replaceAll(RegExp(r'^_'), '');

  String _type(JType t) {
    if (t is JNullable) return '${_type(t.inner)} | nil';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'String.t()',
        'int' => 'integer()',
        'double' => 'float()',
        'bool' => 'boolean()',
        _ => 'any()',
      };
    }
    if (t is JArray) return 'list(${_type(t.item)})';
    if (t is JObject) return '${t.className}.t()';
    return 'any()';
  }

  String _fromMap(JType t, String expr) {
    if (t is JNullable) {
      final inner = t.inner;
      if (inner is JObject) {
        return 'if $expr, do: ${inner.className}.from_map($expr)';
      }
      return expr;
    }
    if (t is JObject) return '${t.className}.from_map($expr)';
    if (t is JArray && t.item is JObject) {
      return 'Enum.map($expr || [], &${(t.item as JObject).className}.from_map/1)';
    }
    return expr;
  }

  String _toMap(JType t, String expr) {
    if (t is JNullable) return _toMap(t.inner, expr);
    if (t is JObject) return '${t.className}.to_map($expr)';
    if (t is JArray && t.item is JObject) {
      return 'Enum.map($expr, &${(t.item as JObject).className}.to_map/1)';
    }
    return expr;
  }
}

// ── C++ ──────────────────────────────────────────────────────────────────────

class CppGenerator extends CodeGenerator {
  final CppSettings settings;

  CppGenerator({CppSettings? settings})
      : settings = settings ?? CppSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();

    // Includes
    buf.writeln('#include <string>');
    buf.writeln('#include <vector>');
    if (settings.useOptional) buf.writeln('#include <optional>');
    if (settings.jsonLib == 'nlohmann') {
      buf.writeln('#include <nlohmann/json.hpp>');
    }
    buf.writeln();

    for (final cls in classes.reversed) {
      _writeStruct(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeStruct(StringBuffer buf, JObject obj) {
    buf.writeln('struct ${obj.className} {');
    for (final e in obj.fields.entries) {
      buf.writeln('    ${_type(e.value)} ${toCamelCase(e.key)};');
    }
    buf.writeln('};');

    if (settings.jsonLib == 'nlohmann') {
      buf.writeln();
      _writeFromJson(buf, obj);
      buf.writeln();
      _writeToJson(buf, obj);
    }
  }

  void _writeFromJson(StringBuffer buf, JObject obj) {
    buf.writeln(
        'inline void from_json(const nlohmann::json& j, ${obj.className}& o) {');
    for (final e in obj.fields.entries) {
      final camel = toCamelCase(e.key);
      if (e.value is JNullable) {
        buf.writeln(
            '    if (j.contains("${e.key}") && !j.at("${e.key}").is_null())');
        final inner = (e.value as JNullable).inner;
        buf.writeln(
            '        o.$camel = j.at("${e.key}").get<${_type(inner)}>();');
      } else if (e.value is JObject) {
        buf.writeln(
            '    j.at("${e.key}").get_to(o.$camel);');
      } else {
        buf.writeln('    j.at("${e.key}").get_to(o.$camel);');
      }
    }
    buf.writeln('}');
  }

  void _writeToJson(StringBuffer buf, JObject obj) {
    buf.writeln(
        'inline void to_json(nlohmann::json& j, const ${obj.className}& o) {');
    buf.writeln('    j = nlohmann::json{');
    for (final e in obj.fields.entries) {
      final camel = toCamelCase(e.key);
      buf.writeln('        {"${e.key}", o.$camel},');
    }
    buf.writeln('    };');
    buf.writeln('}');
  }

  String _type(JType t) {
    if (t is JNullable) {
      return settings.useOptional
          ? 'std::optional<${_type(t.inner)}>'
          : '${_type(t.inner)}*';
    }
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'std::string',
        'int' => 'int64_t',
        'double' => 'double',
        'bool' => 'bool',
        _ => 'nlohmann::json',
      };
    }
    if (t is JArray) return 'std::vector<${_type(t.item)}>';
    if (t is JObject) return t.className;
    return 'nlohmann::json';
  }
}

// ── Java ─────────────────────────────────────────────────────────────────────

class JavaGenerator extends CodeGenerator {
  final JavaSettings settings;

  JavaGenerator({JavaSettings? settings})
      : settings = settings ?? JavaSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();

    // Imports
    switch (settings.serialization) {
      case 'jackson':
        buf.writeln(
            'import com.fasterxml.jackson.annotation.JsonProperty;');
        if (settings.lombok) buf.writeln('import lombok.Data;');
      case 'gson':
        buf.writeln('import com.google.gson.annotations.SerializedName;');
        if (settings.lombok) buf.writeln('import lombok.Data;');
      case 'none':
        if (settings.lombok) buf.writeln('import lombok.Data;');
    }
    buf.writeln();

    for (final cls in classes.reversed) {
      _writeClass(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeClass(StringBuffer buf, JObject obj) {
    if (settings.lombok) buf.writeln('@Data');
    buf.writeln('public class ${obj.className} {');
    final entries = obj.fields.entries.toList();
    for (final e in entries) {
      final annotation = switch (settings.serialization) {
        'jackson' => '    @JsonProperty("${e.key}")',
        'gson' => '    @SerializedName("${e.key}")',
        _ => '',
      };
      if (annotation.isNotEmpty) buf.writeln(annotation);
      buf.writeln('    private ${_type(e.value)} ${toCamelCase(e.key)};');
    }

    if (!settings.lombok) {
      // Generate getters and setters
      for (final e in entries) {
        final camel = toCamelCase(e.key);
        final pascal = camel[0].toUpperCase() + camel.substring(1);
        final type = _type(e.value);
        buf.writeln();
        buf.writeln('    public $type get$pascal() { return $camel; }');
        buf.writeln(
            '    public void set$pascal($type $camel) { this.$camel = $camel; }');
      }
    }
    buf.writeln('}');
  }

  String _type(JType t) {
    if (t is JNullable) return _type(t.inner);
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'String',
        'int' => 'Long',
        'double' => 'Double',
        'bool' => 'Boolean',
        _ => 'Object',
      };
    }
    if (t is JArray) return 'List<${_type(t.item)}>';
    if (t is JObject) return t.className;
    return 'Object';
  }
}

// ── PHP ──────────────────────────────────────────────────────────────────────

class PhpGenerator extends CodeGenerator {
  final PhpSettings settings;

  PhpGenerator({PhpSettings? settings})
      : settings = settings ?? PhpSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    buf.writeln('<?php');
    buf.writeln();
    if (settings.strictTypes) buf.writeln('declare(strict_types=1);');
    buf.writeln();
    for (final cls in classes.reversed) {
      _writeClass(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeClass(StringBuffer buf, JObject obj) {
    final entries = obj.fields.entries.toList();
    if (settings.phpVersion == '8') {
      // Constructor promotion
      buf.writeln('class ${obj.className}');
      buf.writeln('{');
      buf.writeln('    public function __construct(');
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final comma = i < entries.length - 1 ? ',' : '';
        final def = e.value is JNullable ? ' = null' : '';
        buf.writeln(
            '        public readonly ${_type(e.value)} \$${toCamelCase(e.key)}$def$comma');
      }
      buf.writeln('    ) {}');
    } else {
      // PHP 7 style
      buf.writeln('class ${obj.className}');
      buf.writeln('{');
      for (final e in entries) {
        buf.writeln('    /** @var ${_phpDocType(e.value)} */');
        buf.writeln('    public \$${toCamelCase(e.key)};');
      }
      buf.writeln();
    }
    buf.writeln();

    // fromArray
    final ret = settings.phpVersion == '8' ? 'static' : 'self';
    buf.writeln('    public static function fromArray(array \$data): $ret');
    buf.writeln('    {');
    if (settings.phpVersion == '8') {
      buf.writeln('        return new static(');
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final camel = toCamelCase(e.key);
        final comma = i < entries.length - 1 ? ',' : '';
        buf.writeln(
            '            $camel: ${_fromArray(e.value, "\$data['${e.key}']")}$comma');
      }
      buf.writeln('        );');
    } else {
      buf.writeln('        \$obj = new self();');
      for (final e in entries) {
        final camel = toCamelCase(e.key);
        buf.writeln(
            '        \$obj->$camel = ${_fromArray(e.value, "\$data['${e.key}']")};');
      }
      buf.writeln('        return \$obj;');
    }
    buf.writeln('    }');
    buf.writeln();

    // toArray
    buf.writeln('    public function toArray(): array');
    buf.writeln('    {');
    buf.writeln('        return [');
    for (final e in entries) {
      final camel = toCamelCase(e.key);
      buf.writeln(
          "            '${e.key}' => ${_toArray(e.value, "\$this->$camel")},");
    }
    buf.writeln('        ];');
    buf.writeln('    }');
    buf.writeln('}');
  }

  String _type(JType t) {
    if (t is JNullable) return '?${_type(t.inner)}';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'string',
        'int' => 'int',
        'double' => 'float',
        'bool' => 'bool',
        _ => 'mixed',
      };
    }
    if (t is JArray) return 'array';
    if (t is JObject) return t.className;
    return 'mixed';
  }

  String _phpDocType(JType t) {
    if (t is JNullable) return '${_phpDocType(t.inner)}|null';
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'string',
        'int' => 'int',
        'double' => 'float',
        'bool' => 'bool',
        _ => 'mixed',
      };
    }
    if (t is JArray) return 'array';
    if (t is JObject) return t.className;
    return 'mixed';
  }

  String _fromArray(JType t, String expr) {
    if (t is JNullable) {
      final inner = t.inner;
      if (inner is JObject) {
        return 'isset($expr) ? ${inner.className}::fromArray($expr) : null';
      }
      return '$expr ?? null';
    }
    if (t is JObject) return '${t.className}::fromArray($expr)';
    if (t is JArray && t.item is JObject) {
      return 'array_map(fn(\$e) => ${(t.item as JObject).className}::fromArray(\$e), $expr ?? [])';
    }
    return expr;
  }

  String _toArray(JType t, String expr) {
    if (t is JNullable) return _toArray(t.inner, expr);
    if (t is JObject) return '$expr?->toArray()';
    if (t is JArray && t.item is JObject) {
      return 'array_map(fn(\$e) => \$e->toArray(), $expr ?? [])';
    }
    return expr;
  }
}

// ── Objective-C ───────────────────────────────────────────────────────────────

class ObjcGenerator extends CodeGenerator {
  final ObjcSettings settings;

  ObjcGenerator({ObjcSettings? settings})
      : settings = settings ?? ObjcSettings();

  @override
  String generate(JObject root) {
    final classes = collectClasses(root);
    final buf = StringBuffer();
    buf.writeln('#import <Foundation/Foundation.h>');
    buf.writeln();
    // Forward declarations for nested classes
    if (classes.length > 1) {
      for (final cls in classes) {
        buf.writeln('@class ${cls.className};');
      }
      buf.writeln();
    }
    for (final cls in classes.reversed) {
      _writeInterface(buf, cls);
      buf.writeln();
    }
    buf.writeln();
    for (final cls in classes.reversed) {
      _writeImplementation(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeInterface(StringBuffer buf, JObject obj) {
    if (settings.useNonnull) buf.writeln('NS_ASSUME_NONNULL_BEGIN');
    buf.writeln();
    buf.writeln('@interface ${obj.className} : NSObject');
    buf.writeln();
    for (final e in obj.fields.entries) {
      final nullable = e.value is JNullable ? ', nullable' : '';
      buf.writeln(
          '@property (nonatomic$nullable) ${_type(e.value)} ${toCamelCase(e.key)};');
    }
    buf.writeln();
    buf.writeln(
        '+ (instancetype)modelFromDictionary:(NSDictionary *)dict;');
    buf.writeln('- (NSDictionary *)toDictionary;');
    buf.writeln();
    buf.writeln('@end');
    if (settings.useNonnull) buf.writeln('NS_ASSUME_NONNULL_END');
  }

  void _writeImplementation(StringBuffer buf, JObject obj) {
    buf.writeln('@implementation ${obj.className}');
    buf.writeln();
    buf.writeln(
        '+ (instancetype)modelFromDictionary:(NSDictionary *)dict {');
    buf.writeln('    ${obj.className} *obj = [[${obj.className} alloc] init];');
    for (final e in obj.fields.entries) {
      final camel = toCamelCase(e.key);
      buf.writeln('    obj.$camel = ${_fromDict(e.value, "dict[@\"${e.key}\"]")};');
    }
    buf.writeln('    return obj;');
    buf.writeln('}');
    buf.writeln();
    buf.writeln('- (NSDictionary *)toDictionary {');
    buf.writeln('    NSMutableDictionary *dict = [NSMutableDictionary dictionary];');
    for (final e in obj.fields.entries) {
      final camel = toCamelCase(e.key);
      final val = _toDict(e.value, "self.$camel");
      buf.writeln('    dict[@"${e.key}"] = $val ?: [NSNull null];');
    }
    buf.writeln('    return [dict copy];');
    buf.writeln('}');
    buf.writeln();
    buf.writeln('@end');
  }

  String _type(JType t) {
    if (t is JNullable) return _type(t.inner);
    if (t is JPrimitive) {
      return switch (t.name) {
        'String' => 'NSString *',
        'int' => 'NSInteger',
        'double' => 'double',
        'bool' => 'BOOL',
        _ => 'id',
      };
    }
    if (t is JArray) return 'NSArray *';
    if (t is JObject) return '${t.className} *';
    return 'id';
  }

  String _fromDict(JType t, String expr) {
    if (t is JNullable) return _fromDict(t.inner, expr);
    if (t is JPrimitive) {
      return switch (t.name) {
        'int' => '[$expr integerValue]',
        'double' => '[$expr doubleValue]',
        'bool' => '[$expr boolValue]',
        _ => expr,
      };
    }
    if (t is JObject) {
      return '[${t.className} modelFromDictionary:$expr]';
    }
    if (t is JArray && t.item is JObject) {
      final cls = (t.item as JObject).className;
      return '[($expr ?: @[]) mapObjectsUsingBlock:^id(id e, NSUInteger i) { return [$cls modelFromDictionary:e]; }]';
    }
    return expr;
  }

  String _toDict(JType t, String expr) {
    if (t is JNullable) return _toDict(t.inner, expr);
    if (t is JPrimitive) {
      return switch (t.name) {
        'int' => '@($expr)',
        'double' => '@($expr)',
        'bool' => '@($expr)',
        _ => expr,
      };
    }
    if (t is JObject) return '[$expr toDictionary]';
    if (t is JArray && t.item is JObject) {
      return '[$expr mapObjectsUsingBlock:^id(id e, NSUInteger i) { return [e toDictionary]; }]';
    }
    return expr;
  }
}
