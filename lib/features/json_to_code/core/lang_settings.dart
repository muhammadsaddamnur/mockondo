// ── Per-language generator settings ──────────────────────────────────────────

class DartSettings {
  // Language tab
  bool nullSafety;
  bool typesOnly;
  bool allRequired;
  bool allOptional;
  bool immutable;
  bool copyWith;
  bool equatable;
  // Other tab
  String partDirective;
  bool useMapNames;
  bool freezed;
  bool jsonSerializable;
  bool hiveAdapters;

  DartSettings({
    this.nullSafety = true,
    this.typesOnly = false,
    this.allRequired = false,
    this.allOptional = false,
    this.immutable = true,
    this.copyWith = false,
    this.equatable = false,
    this.partDirective = '',
    this.useMapNames = false,
    this.freezed = false,
    this.jsonSerializable = false,
    this.hiveAdapters = false,
  });

  DartSettings copyWithValues({
    bool? nullSafety,
    bool? typesOnly,
    bool? allRequired,
    bool? allOptional,
    bool? immutable,
    bool? copyWith,
    bool? equatable,
    String? partDirective,
    bool? useMapNames,
    bool? freezed,
    bool? jsonSerializable,
    bool? hiveAdapters,
  }) =>
      DartSettings(
        nullSafety: nullSafety ?? this.nullSafety,
        typesOnly: typesOnly ?? this.typesOnly,
        allRequired: allRequired ?? this.allRequired,
        allOptional: allOptional ?? this.allOptional,
        immutable: immutable ?? this.immutable,
        copyWith: copyWith ?? this.copyWith,
        equatable: equatable ?? this.equatable,
        partDirective: partDirective ?? this.partDirective,
        useMapNames: useMapNames ?? this.useMapNames,
        freezed: freezed ?? this.freezed,
        jsonSerializable: jsonSerializable ?? this.jsonSerializable,
        hiveAdapters: hiveAdapters ?? this.hiveAdapters,
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

class JavaScriptSettings {
  bool useESModules;
  bool jsdoc;

  JavaScriptSettings({
    this.useESModules = true,
    this.jsdoc = true,
  });

  JavaScriptSettings copyWithValues({bool? useESModules, bool? jsdoc}) =>
      JavaScriptSettings(
        useESModules: useESModules ?? this.useESModules,
        jsdoc: jsdoc ?? this.jsdoc,
      );
}

class RustSettings {
  bool deriveDebug;
  bool deriveClone;
  bool derivePartialEq;
  bool serde;

  RustSettings({
    this.deriveDebug = true,
    this.deriveClone = true,
    this.derivePartialEq = false,
    this.serde = true,
  });

  RustSettings copyWithValues({
    bool? deriveDebug,
    bool? deriveClone,
    bool? derivePartialEq,
    bool? serde,
  }) =>
      RustSettings(
        deriveDebug: deriveDebug ?? this.deriveDebug,
        deriveClone: deriveClone ?? this.deriveClone,
        derivePartialEq: derivePartialEq ?? this.derivePartialEq,
        serde: serde ?? this.serde,
      );
}

class RubySettings {
  bool attrAccessor;
  bool frozen;

  RubySettings({
    this.attrAccessor = true,
    this.frozen = true,
  });

  RubySettings copyWithValues({bool? attrAccessor, bool? frozen}) =>
      RubySettings(
        attrAccessor: attrAccessor ?? this.attrAccessor,
        frozen: frozen ?? this.frozen,
      );
}

class ElixirSettings {
  bool enforceKeys;
  bool typeSpec;

  ElixirSettings({
    this.enforceKeys = true,
    this.typeSpec = true,
  });

  ElixirSettings copyWithValues({bool? enforceKeys, bool? typeSpec}) =>
      ElixirSettings(
        enforceKeys: enforceKeys ?? this.enforceKeys,
        typeSpec: typeSpec ?? this.typeSpec,
      );
}

class CppSettings {
  /// 'nlohmann' | 'none'
  String jsonLib;
  bool useOptional;

  CppSettings({
    this.jsonLib = 'nlohmann',
    this.useOptional = true,
  });

  CppSettings copyWithValues({String? jsonLib, bool? useOptional}) =>
      CppSettings(
        jsonLib: jsonLib ?? this.jsonLib,
        useOptional: useOptional ?? this.useOptional,
      );
}

class JavaSettings {
  /// 'jackson' | 'gson' | 'none'
  String serialization;
  bool lombok;

  JavaSettings({
    this.serialization = 'jackson',
    this.lombok = false,
  });

  JavaSettings copyWithValues({String? serialization, bool? lombok}) =>
      JavaSettings(
        serialization: serialization ?? this.serialization,
        lombok: lombok ?? this.lombok,
      );
}

class PhpSettings {
  /// '7' | '8'
  String phpVersion;
  bool strictTypes;

  PhpSettings({
    this.phpVersion = '8',
    this.strictTypes = true,
  });

  PhpSettings copyWithValues({String? phpVersion, bool? strictTypes}) =>
      PhpSettings(
        phpVersion: phpVersion ?? this.phpVersion,
        strictTypes: strictTypes ?? this.strictTypes,
      );
}

class ObjcSettings {
  bool useNonnull;

  ObjcSettings({this.useNonnull = true});

  ObjcSettings copyWithValues({bool? useNonnull}) =>
      ObjcSettings(useNonnull: useNonnull ?? this.useNonnull);
}
