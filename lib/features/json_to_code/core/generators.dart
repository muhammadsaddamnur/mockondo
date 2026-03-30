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

    if (settings.equatable) {
      buf.writeln("import 'package:equatable/equatable.dart';");
      buf.writeln();
    }

    for (final cls in classes.reversed) {
      _writeClass(buf, cls);
      buf.writeln();
    }
    return buf.toString().trimRight();
  }

  void _writeClass(StringBuffer buf, JObject obj) {
    final fieldMod = settings.immutable ? 'final ' : '';
    final equatableMixin =
        settings.equatable ? ' extends Equatable' : '';

    buf.writeln('class ${obj.className}$equatableMixin {');
    for (final e in obj.fields.entries) {
      buf.writeln('  $fieldMod${_type(e.value)} ${toCamelCase(e.key)};');
    }
    buf.writeln();
    buf.writeln('  ${obj.className}({');
    for (final e in obj.fields.entries) {
      final isNullable = e.value is JNullable;
      final req = isNullable ? '' : 'required ';
      buf.writeln('    ${req}this.${toCamelCase(e.key)},');
    }
    buf.writeln('  });');
    buf.writeln();

    // fromJson
    buf.writeln(
        '  factory ${obj.className}.fromJson(Map<String, dynamic> json) =>');
    buf.writeln('      ${obj.className}(');
    for (final e in obj.fields.entries) {
      final camel = toCamelCase(e.key);
      buf.writeln("        $camel: ${_fromJson(e.value, "json['${e.key}']")},");
    }
    buf.writeln('      );');
    buf.writeln();

    // toJson
    buf.writeln('  Map<String, dynamic> toJson() => {');
    for (final e in obj.fields.entries) {
      final camel = toCamelCase(e.key);
      buf.writeln("    '${e.key}': ${_toJson(e.value, camel)},");
    }
    buf.writeln('  };');

    // copyWith
    if (settings.copyWith) {
      buf.writeln();
      buf.writeln('  ${obj.className} copyWith({');
      for (final e in obj.fields.entries) {
        buf.writeln('    ${_type(e.value)}? ${toCamelCase(e.key)},');
      }
      buf.writeln('  }) =>');
      buf.writeln('      ${obj.className}(');
      for (final e in obj.fields.entries) {
        final camel = toCamelCase(e.key);
        buf.writeln('        $camel: $camel ?? this.$camel,');
      }
      buf.writeln('      );');
    }

    // equatable props
    if (settings.equatable) {
      buf.writeln();
      final props =
          obj.fields.keys.map(toCamelCase).join(', ');
      buf.writeln('  @override');
      buf.writeln('  List<Object?> get props => [$props];');
    }

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
