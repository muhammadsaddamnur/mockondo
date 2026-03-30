// ── Type model ──────────────────────────────────────────────────────────────

abstract class JType {
  const JType();
}

class JPrimitive extends JType {
  final String name;
  const JPrimitive(this.name);
}

class JNullable extends JType {
  final JType inner;
  const JNullable(this.inner);
}

class JArray extends JType {
  final JType item;
  const JArray(this.item);
}

class JObject extends JType {
  final String className;
  final Map<String, JType> fields;
  const JObject(this.className, this.fields);
}

// ── Inference ────────────────────────────────────────────────────────────────

JType inferType(dynamic value, String hint) {
  if (value == null) return const JNullable(JPrimitive('dynamic'));
  if (value is bool) return const JPrimitive('bool');
  if (value is int) return const JPrimitive('int');
  if (value is double) return const JPrimitive('double');
  if (value is String) return const JPrimitive('String');
  if (value is List) {
    if (value.isEmpty) return const JArray(JPrimitive('dynamic'));
    return JArray(inferType(value.first, '${toPascalCase(hint)}Item'));
  }
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    return JObject(
      toPascalCase(hint),
      {
        for (final e in map.entries)
          e.key: e.value == null
              ? const JNullable(JPrimitive('dynamic'))
              : inferType(e.value, e.key),
      },
    );
  }
  return const JPrimitive('dynamic');
}

/// Depth-first collection of all [JObject] nodes (outer first).
List<JObject> collectClasses(JType root) {
  final result = <JObject>[];
  final seen = <String>{};
  void walk(JType t) {
    if (t is JObject) {
      if (seen.add(t.className)) {
        result.add(t);
        for (final f in t.fields.values) {
          walk(f);
        }
      }
    } else if (t is JArray) {
      walk(t.item);
    } else if (t is JNullable) {
      walk(t.inner);
    }
  }

  walk(root);
  return result;
}

String toPascalCase(String s) {
  if (s.isEmpty) return 'Unknown';
  return s
      .split(RegExp(r'[_\-\s\.]+'))
      .map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1))
      .join('');
}

String toCamelCase(String s) {
  final p = toPascalCase(s);
  if (p.isEmpty) return s;
  return p[0].toLowerCase() + p.substring(1);
}
