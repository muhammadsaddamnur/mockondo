import 'package:mockondo/core/server.dart';

// ── WebSocket mock models ───────────────────────────────────────────────────────

/// A time-based message that the server pushes to every connected client
/// automatically, either once after a delay or repeatedly on an interval.
class WsScheduledMessage {
  final String id;
  bool enabled;

  /// The text to push to the client.
  String message;

  /// Milliseconds to wait before the first send.
  int delayMs;

  /// Whether to keep sending on [intervalMs] after the first send.
  bool repeat;

  /// Milliseconds between repeated sends. Only used when [repeat] is `true`.
  int intervalMs;

  WsScheduledMessage({
    required this.id,
    this.enabled = true,
    this.message = '',
    this.delayMs = 1000,
    this.repeat = false,
    this.intervalMs = 5000,
  });

  WsScheduledMessage copyWith({
    String? id,
    bool? enabled,
    String? message,
    int? delayMs,
    bool? repeat,
    int? intervalMs,
  }) => WsScheduledMessage(
    id: id ?? this.id,
    enabled: enabled ?? this.enabled,
    message: message ?? this.message,
    delayMs: delayMs ?? this.delayMs,
    repeat: repeat ?? this.repeat,
    intervalMs: intervalMs ?? this.intervalMs,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'enabled': enabled,
    'message': message,
    'delay_ms': delayMs,
    'repeat': repeat,
    'interval_ms': intervalMs,
  };

  factory WsScheduledMessage.fromJson(Map<String, dynamic> json) =>
      WsScheduledMessage(
        id: json['id'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        message: json['message'] as String? ?? '',
        delayMs: json['delay_ms'] as int? ?? 1000,
        repeat: json['repeat'] as bool? ?? false,
        intervalMs: json['interval_ms'] as int? ?? 5000,
      );
}

/// A single message-matching rule inside a [WsMockModel].
///
/// When the server receives a message from a WebSocket client, rules are
/// evaluated in order; the first matching rule's [response] is sent back.
class WsMockRule {
  final String id;

  /// The pattern to match against the incoming message text.
  final String pattern;

  /// When `true`, [pattern] is treated as a regular expression.
  final bool isRegex;

  /// The message text to send back when this rule matches.
  final String response;

  WsMockRule({
    required this.id,
    required this.pattern,
    this.isRegex = false,
    required this.response,
  });

  /// Returns `true` if [message] satisfies this rule.
  bool matches(String message) {
    if (isRegex) {
      try {
        return RegExp(pattern).hasMatch(message);
      } catch (_) {
        return false;
      }
    }
    return message == pattern;
  }

  WsMockRule copyWith({
    String? id,
    String? pattern,
    bool? isRegex,
    String? response,
  }) => WsMockRule(
    id: id ?? this.id,
    pattern: pattern ?? this.pattern,
    isRegex: isRegex ?? this.isRegex,
    response: response ?? this.response,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'pattern': pattern,
    'is_regex': isRegex,
    'response': response,
  };

  factory WsMockRule.fromJson(Map<String, dynamic> json) => WsMockRule(
    id: json['id'] as String? ?? '',
    pattern: json['pattern'] as String? ?? '',
    isRegex: json['is_regex'] as bool? ?? false,
    response: json['response'] as String? ?? '',
  );
}

/// A single mock WebSocket endpoint inside a [MockData] project.
///
/// When a client connects to [endpoint], the server optionally sends
/// [onConnectMessage] and then processes incoming messages against [rules].
class WsMockModel {
  bool enable;

  /// URL path for the WebSocket upgrade (e.g. `/ws`, `/chat`).
  String endpoint;

  /// Message sent immediately when a client connects. `null` = silent.
  String? onConnectMessage;

  /// Ordered list of message-matching rules. First match wins.
  List<WsMockRule> rules;

  /// Time-based messages automatically pushed to each connected client.
  List<WsScheduledMessage> scheduledMessages;

  WsMockModel({
    required this.enable,
    required this.endpoint,
    this.onConnectMessage,
    this.rules = const [],
    List<WsScheduledMessage>? scheduledMessages,
  }) : scheduledMessages = scheduledMessages ?? [];

  WsMockModel copyWith({
    bool? enable,
    String? endpoint,
    String? onConnectMessage,
    List<WsMockRule>? rules,
    List<WsScheduledMessage>? scheduledMessages,
  }) => WsMockModel(
    enable: enable ?? this.enable,
    endpoint: endpoint ?? this.endpoint,
    onConnectMessage: onConnectMessage ?? this.onConnectMessage,
    rules: rules ?? this.rules,
    scheduledMessages: scheduledMessages ?? this.scheduledMessages,
  );

  Map<String, dynamic> toJson() => {
    'enable': enable,
    'endpoint': endpoint,
    'on_connect_message': onConnectMessage,
    'rules': rules.map((r) => r.toJson()).toList(),
    'scheduled_messages': scheduledMessages.map((s) => s.toJson()).toList(),
  };

  factory WsMockModel.fromJson(Map<String, dynamic> json) => WsMockModel(
    enable: json['enable'] as bool? ?? false,
    endpoint: json['endpoint'] as String? ?? '/ws',
    onConnectMessage: json['on_connect_message'] as String?,
    rules:
        (json['rules'] as List<dynamic>?)
            ?.map((e) => WsMockRule.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    scheduledMessages:
        (json['scheduled_messages'] as List<dynamic>?)
            ?.map((e) => WsScheduledMessage.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );
}

// ── Project ────────────────────────────────────────────────────────────────────

/// Top-level container for a single mock project.
///
/// Each project has its own host/port and a list of [MockModel] endpoints.
/// [server] is not serialised – it is wired up at runtime after loading.
class MockData {
  int id;
  String name;
  String host;
  int port;
  List<MockModel> mockModels;

  /// WebSocket mock endpoints for this project.
  List<WsMockModel> wsMockModels;

  /// The running HTTP server for this project. `null` when the server is stopped.
  MainServer? server;

  MockData({
    this.id = 0,
    required this.name,
    required this.host,
    required this.port,
    required this.mockModels,
    List<WsMockModel>? wsMockModels,
    this.server,
  }) : wsMockModels = wsMockModels ?? [];

  MockData copyWith({
    int? id,
    String? name,
    String? host,
    int? port,
    List<MockModel>? mockModels,
    List<WsMockModel>? wsMockModels,
    MainServer? server,
  }) {
    return MockData(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      mockModels: mockModels ?? this.mockModels,
      wsMockModels: wsMockModels ?? this.wsMockModels,
      server: server ?? this.server,
    );
  }

  /// Serialises the project to JSON for persistence.
  /// [server] is intentionally excluded – it is a runtime-only object.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'mock_models': mockModels.map((model) => model.toJson()).toList(),
      'ws_mock_models': wsMockModels.map((m) => m.toJson()).toList(),
    };
  }

  factory MockData.fromJson(Map<String, dynamic> json) {
    return MockData(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 8080,
      mockModels:
          (json['mock_models'] as List<dynamic>?)
              ?.map((e) => MockModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      wsMockModels:
          (json['ws_mock_models'] as List<dynamic>?)
              ?.map((e) => WsMockModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      // A fresh server instance is created on load; it starts only when the
      // user presses play.
      server: MainServer(),
    );
  }
}

// ── Endpoint ───────────────────────────────────────────────────────────────────

/// Defines a single mock API endpoint inside a project.
///
/// Each endpoint has an HTTP [method], a path [endpoint], a default
/// [responseBody], and optional [rules] for conditional responses.
class MockModel {
  /// Whether this endpoint is active. Disabled endpoints are skipped when
  /// the server builds its router.
  bool enable;

  /// URL path of the endpoint, e.g. `/api/users` or `/api/users/<id>`.
  String endpoint;

  /// Default HTTP status code returned when no rule matches.
  int statusCode;

  /// Optional artificial delay in milliseconds before the response is sent.
  int? delay;

  /// Optional response headers. Supports `${...}` interpolation placeholders.
  Map<String, Object>? responseHeader;

  /// Default response body (JSON string). Supports `${...}` interpolation.
  String responseBody;

  /// HTTP method: GET, POST, PUT, PATCH, or DELETE.
  String method;

  /// Optional list of conditional rules (pagination, response overrides, etc.).
  List<Rules>? rules;

  MockModel({
    required this.enable,
    required this.endpoint,
    required this.statusCode,
    this.delay,
    this.responseHeader,
    required this.responseBody,
    required this.method,
    this.rules,
  });

  MockModel copyWith({
    bool? enable,
    String? endpoint,
    int? statusCode,
    int? delay,
    Map<String, Object>? responseHeader,
    String? responseBody,
    String? method,
    List<Rules>? rules,
  }) {
    return MockModel(
      enable: enable ?? this.enable,
      endpoint: endpoint ?? this.endpoint,
      statusCode: statusCode ?? this.statusCode,
      delay: delay ?? this.delay,
      responseHeader: responseHeader ?? this.responseHeader,
      responseBody: responseBody ?? this.responseBody,
      method: method ?? this.method,
      rules: rules ?? this.rules,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable': enable,
      'endpoint': endpoint,
      'status_code': statusCode,
      'delay': delay,
      'response_header': responseHeader,
      'response_body': responseBody,
      'method': method,
      'rules': rules?.map((rule) => rule.toJson()).toList(),
    };
  }

  factory MockModel.fromJson(Map<String, dynamic> json) {
    return MockModel(
      enable: json['enable'] as bool? ?? false,
      endpoint: json['endpoint'] as String? ?? '',
      statusCode: json['status_code'] as int? ?? 200,
      delay: json['delay'] as int?,
      responseHeader: (json['response_header'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as Object),
      ),
      responseBody: json['response_body'] as String,
      method: json['method'] as String? ?? '',
      rules:
          (json['rules'] as List<dynamic>?)
              ?.map((e) => Rules.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

// ── Rules ──────────────────────────────────────────────────────────────────────

/// A rule attached to a [MockModel] that can override the default response.
///
/// Rules are evaluated in order; the first matching rule wins.
/// The [type] determines the rule category (e.g. response override, pagination).
/// Metadata such as label, status code, conditions, and logic are stored inside
/// the [rules] map and accessed via [ResponseRulesExt].
class Rules {
  RulesType type;

  /// Flexible metadata bag: label, status_code, logic, conditions list, etc.
  Map<String, dynamic> rules;

  /// The response body to return when this rule matches.
  String response;

  /// Optional response headers for this rule.
  Map<String, Object>? responseHeader;

  Rules({
    required this.type,
    required this.rules,
    required this.response,
    this.responseHeader,
  });

  Rules copyWith({
    RulesType? type,
    Map<String, dynamic>? rules,
    String? response,
    Map<String, Object>? responseHeader,
  }) {
    return Rules(
      type: type ?? this.type,
      rules: rules ?? this.rules,
      response: response ?? this.response,
      responseHeader: responseHeader ?? this.responseHeader,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'rules': rules,
      'response': response,
      if (responseHeader != null) 'response_header': responseHeader,
    };
  }

  factory Rules.fromJson(Map<String, dynamic> json) {
    return Rules(
      type: RulesType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => RulesType.response,
      ),
      rules: json['rules'] as Map<String, dynamic>? ?? {},
      response: json['response'] as String? ?? '',
      responseHeader: (json['response_header'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, v as Object),
      ),
    );
  }
}

// ── Enums ──────────────────────────────────────────────────────────────────────

/// The category of a [Rules] entry.
enum RulesType {
  /// Overrides the default response body/status when conditions match.
  response,

  /// Generates paginated data from a template.
  pagination,

  // Planned features — not yet implemented.
  sorting,
  filtering,
  searching,
}

/// The part of the incoming request that a [ResponseCondition] inspects.
enum ResponseRuleTarget {
  /// A URL query parameter (e.g. `?status=active`).
  queryParam,

  /// An HTTP request header (e.g. `Authorization`).
  requestHeader,

  /// A field inside the JSON request body (supports dot notation).
  bodyField,

  /// A segment of the URL path (zero-based index).
  routeParam,
}

/// How the actual value is compared against the expected value in a condition.
enum ResponseRuleOperator {
  equals,
  notEquals,
  contains,
  notContains,

  /// Matches the actual value against a regular expression pattern.
  regexMatch,

  isEmpty,
  isNotEmpty,
}

/// Whether all conditions must match (AND) or any one is enough (OR).
enum RulesLogic { and, or }

// ── ResponseCondition ──────────────────────────────────────────────────────────

/// A single condition inside a [Rules] entry.
///
/// Specifies which part of the request to inspect ([target]), which field or
/// key to read ([key]), how to compare ([operator]), and the expected [value].
class ResponseCondition {
  final String id;
  final ResponseRuleTarget target;

  /// The field name or key to read from the request (e.g. query param name,
  /// header name, body field path, or path segment index).
  final String key;

  final ResponseRuleOperator operator;

  /// The expected value to compare against (unused for [isEmpty]/[isNotEmpty]).
  final String value;

  ResponseCondition({
    required this.id,
    required this.target,
    required this.key,
    required this.operator,
    required this.value,
  });

  ResponseCondition copyWith({
    String? id,
    ResponseRuleTarget? target,
    String? key,
    ResponseRuleOperator? operator,
    String? value,
  }) {
    return ResponseCondition(
      id: id ?? this.id,
      target: target ?? this.target,
      key: key ?? this.key,
      operator: operator ?? this.operator,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'target': target.name,
    'key': key,
    'operator': operator.name,
    'value': value,
  };

  factory ResponseCondition.fromJson(Map<String, dynamic> json) =>
      ResponseCondition(
        id: json['id'] as String? ?? '',
        target: ResponseRuleTarget.values.firstWhere(
          (e) => e.name == json['target'],
          orElse: () => ResponseRuleTarget.queryParam,
        ),
        key: json['key'] as String? ?? '',
        operator: ResponseRuleOperator.values.firstWhere(
          (e) => e.name == json['operator'],
          orElse: () => ResponseRuleOperator.equals,
        ),
        value: json['value'] as String? ?? '',
      );
}

// ── Extension helpers ──────────────────────────────────────────────────────────

/// Typed getters for the metadata stored in [Rules.rules].
///
/// The underlying map stores everything as `dynamic` for flexibility;
/// this extension provides safe, typed access to common fields.
extension ResponseRulesExt on Rules {
  /// Human-readable label shown in the Rules tab of the UI.
  String get label => rules['label'] as String? ?? '';

  /// HTTP status code to return when this rule matches.
  int get ruleStatusCode =>
      rules['status_code'] is int
          ? rules['status_code'] as int
          : int.tryParse(rules['status_code']?.toString() ?? '') ?? 200;

  /// Whether all conditions must match (AND) or any one suffices (OR).
  RulesLogic get logic =>
      (rules['logic'] as String?) == 'or' ? RulesLogic.or : RulesLogic.and;

  /// The list of conditions that guard this rule.
  List<ResponseCondition> get conditions {
    final list = rules['conditions'] as List<dynamic>? ?? [];
    return list
        .map((e) => ResponseCondition.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
