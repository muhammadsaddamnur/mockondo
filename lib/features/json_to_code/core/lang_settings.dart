// ── Per-language generator settings ──────────────────────────────────────────

class DartSettings {
  bool nullSafety;
  bool immutable;
  bool copyWith;
  bool equatable;

  DartSettings({
    this.nullSafety = true,
    this.immutable = true,
    this.copyWith = false,
    this.equatable = false,
  });

  DartSettings copyWithValues({
    bool? nullSafety,
    bool? immutable,
    bool? copyWith,
    bool? equatable,
  }) =>
      DartSettings(
        nullSafety: nullSafety ?? this.nullSafety,
        immutable: immutable ?? this.immutable,
        copyWith: copyWith ?? this.copyWith,
        equatable: equatable ?? this.equatable,
      );
}

class TypeScriptSettings {
  bool useType;
  bool readonly;
  bool undefinedForNull;

  TypeScriptSettings({
    this.useType = false,
    this.readonly = false,
    this.undefinedForNull = false,
  });

  TypeScriptSettings copyWithValues({
    bool? useType,
    bool? readonly,
    bool? undefinedForNull,
  }) =>
      TypeScriptSettings(
        useType: useType ?? this.useType,
        readonly: readonly ?? this.readonly,
        undefinedForNull: undefinedForNull ?? this.undefinedForNull,
      );
}

class KotlinSettings {
  /// 'gson' | 'moshi' | 'kotlinx'
  String serialization;
  bool mutable;

  KotlinSettings({
    this.serialization = 'gson',
    this.mutable = false,
  });

  KotlinSettings copyWithValues({
    String? serialization,
    bool? mutable,
  }) =>
      KotlinSettings(
        serialization: serialization ?? this.serialization,
        mutable: mutable ?? this.mutable,
      );
}

class SwiftSettings {
  bool useClass;
  /// 'internal' | 'public'
  String accessLevel;

  SwiftSettings({
    this.useClass = false,
    this.accessLevel = 'internal',
  });

  SwiftSettings copyWithValues({
    bool? useClass,
    String? accessLevel,
  }) =>
      SwiftSettings(
        useClass: useClass ?? this.useClass,
        accessLevel: accessLevel ?? this.accessLevel,
      );
}

class PythonSettings {
  /// 'dataclass' | 'typeddict' | 'attrs'
  String style;
  bool modernUnion;

  PythonSettings({
    this.style = 'dataclass',
    this.modernUnion = false,
  });

  PythonSettings copyWithValues({
    String? style,
    bool? modernUnion,
  }) =>
      PythonSettings(
        style: style ?? this.style,
        modernUnion: modernUnion ?? this.modernUnion,
      );
}

class GoSettings {
  String packageName;
  bool omitempty;

  GoSettings({
    this.packageName = 'main',
    this.omitempty = false,
  });

  GoSettings copyWithValues({
    String? packageName,
    bool? omitempty,
  }) =>
      GoSettings(
        packageName: packageName ?? this.packageName,
        omitempty: omitempty ?? this.omitempty,
      );
}
