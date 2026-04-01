import 'dart:convert';

// ── KeyValuePair ──────────────────────────────────────────────────────────────

/// A single key-value entry used for request headers, query params, and form
/// data in the HTTP client.
///
/// [enabled] lets the user toggle an entry on/off without deleting it.
class KeyValuePair {
  String key;
  String value;

  /// When `false` this entry is excluded when building the request.
  bool enabled;

  KeyValuePair({this.key = '', this.value = '', this.enabled = true});

  KeyValuePair copyWith({String? key, String? value, bool? enabled}) =>
      KeyValuePair(
        key: key ?? this.key,
        value: value ?? this.value,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'enabled': enabled,
  };

  factory KeyValuePair.fromJson(Map<String, dynamic> json) => KeyValuePair(
    key: json['key'] as String? ?? '',
    value: json['value'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
  );
}

// ── RequestFormField ─────────────────────────────────────────────────────────────────

/// Type of a form-data field.
enum RequestFormFieldType { text, file }

/// A single entry in a multipart/form-data request body.
///
/// When [type] is [RequestFormFieldType.file], [filePath] holds the absolute path to
/// the selected file and [value] is used as the display filename fallback.
/// When [type] is [RequestFormFieldType.text], [value] is the plain text value.
class RequestFormField {
  String key;
  String value;
  bool enabled;
  RequestFormFieldType type;
  String? filePath;

  RequestFormField({
    this.key = '',
    this.value = '',
    this.enabled = true,
    this.type = RequestFormFieldType.text,
    this.filePath,
  });

  String get displayFileName =>
      filePath != null ? filePath!.split('/').last : value;

  RequestFormField copyWith({
    String? key,
    String? value,
    bool? enabled,
    RequestFormFieldType? type,
    String? filePath,
  }) =>
      RequestFormField(
        key: key ?? this.key,
        value: value ?? this.value,
        enabled: enabled ?? this.enabled,
        type: type ?? this.type,
        filePath: filePath ?? this.filePath,
      );

  Map<String, dynamic> toJson() => {
    'key': key,
    'value': value,
    'enabled': enabled,
    'type': type.name,
    'file_path': filePath,
  };

  factory RequestFormField.fromJson(Map<String, dynamic> json) => RequestFormField(
    key: json['key'] as String? ?? '',
    value: json['value'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    type: RequestFormFieldType.values.firstWhere(
      (t) => t.name == (json['type'] as String? ?? 'text'),
      orElse: () => RequestFormFieldType.text,
    ),
    filePath: json['file_path'] as String?,
  );
}

// ── Enums ─────────────────────────────────────────────────────────────────────

/// How the request body is encoded when sending.
enum RequestBodyType {
  /// No body is sent.
  none,

  /// Body is sent as raw JSON text.
  json,

  /// Body is sent as plain text.
  text,

  /// Body is URL-encoded (`application/x-www-form-urlencoded`).
  formData,

  /// Body is raw binary file bytes. The [HttpRequestItem.body] field holds
  /// the absolute file path chosen by the user.
  binary,
}

// ── HttpRequestItem ───────────────────────────────────────────────────────────

/// A saved HTTP request in the client sidebar.
///
/// Requests are persisted to SharedPreferences and can be organised into
/// [HttpRequestGroup]s via [groupId].
class HttpRequestItem {
  /// Stable UUID used to identify the request across saves.
  final String id;

  /// Display name shown in the sidebar.
  String name;

  /// HTTP method (GET, POST, PUT, PATCH, DELETE, HEAD).
  String method;

  /// Target URL. Supports interpolation placeholders.
  String url;

  /// Request headers. Supports interpolation placeholders in values.
  List<KeyValuePair> headers;

  /// URL query parameters appended to [url] before sending.
  List<KeyValuePair> params;

  /// Raw request body (used when [bodyType] is [RequestBodyType.json] or
  /// [RequestBodyType.text]).
  String body;

  /// Determines how [body] / [formData] is encoded.
  RequestBodyType bodyType;

  /// Fields used when [bodyType] is [RequestBodyType.formData].
  /// Each field can be text or a file (multipart/form-data).
  List<RequestFormField> formData;

  /// ID of the [HttpRequestGroup] this request belongs to, or `null` if
  /// the request is ungrouped.
  String? groupId;

  HttpRequestItem({
    required this.id,
    this.name = 'New Request',
    this.method = 'GET',
    this.url = '',
    List<KeyValuePair>? headers,
    List<KeyValuePair>? params,
    this.body = '',
    this.bodyType = RequestBodyType.json,
    List<RequestFormField>? formData,
    this.groupId,
  })  : headers = headers ?? [],
        params = params ?? [],
        formData = formData ?? [];

  /// Returns a copy with only the specified fields changed.
  /// [id] and [groupId] are preserved from the original.
  HttpRequestItem copyWith({
    String? name,
    String? method,
    String? url,
    List<KeyValuePair>? headers,
    List<KeyValuePair>? params,
    String? body,
    RequestBodyType? bodyType,
    List<RequestFormField>? formData,
  }) => HttpRequestItem(
    id: id,
    name: name ?? this.name,
    method: method ?? this.method,
    url: url ?? this.url,
    headers: headers ?? this.headers,
    params: params ?? this.params,
    body: body ?? this.body,
    bodyType: bodyType ?? this.bodyType,
    formData: formData ?? this.formData,
    groupId: groupId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'method': method,
    'url': url,
    'headers': headers.map((e) => e.toJson()).toList(),
    'params': params.map((e) => e.toJson()).toList(),
    'body': body,
    'body_type': bodyType.name,
    'form_data': formData.map((e) => e.toJson()).toList(),
    'group_id': groupId,
  };

  factory HttpRequestItem.fromJson(Map<String, dynamic> json) =>
      HttpRequestItem(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'New Request',
        method: json['method'] as String? ?? 'GET',
        url: json['url'] as String? ?? '',
        headers: (json['headers'] as List<dynamic>?)
                ?.map((e) => KeyValuePair.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        params: (json['params'] as List<dynamic>?)
                ?.map((e) => KeyValuePair.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        body: json['body'] as String? ?? '',
        bodyType: RequestBodyType.values.firstWhere(
          (e) => e.name == json['body_type'],
          orElse: () => RequestBodyType.json,
        ),
        formData: (json['form_data'] as List<dynamic>?)
                ?.map((e) => RequestFormField.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        groupId: json['group_id'] as String?,
      );
}

// ── HttpRequestGroup ──────────────────────────────────────────────────────────

/// A collapsible folder in the HTTP client sidebar that groups related
/// [HttpRequestItem]s together.
class HttpRequestGroup {
  /// Stable UUID used to identify the group across saves.
  final String id;

  String name;

  /// Whether the group is expanded in the sidebar (showing its requests).
  bool isExpanded;

  HttpRequestGroup({
    required this.id,
    required this.name,
    this.isExpanded = true,
  });

  HttpRequestGroup copyWith({String? name, bool? isExpanded}) =>
      HttpRequestGroup(
        id: id,
        name: name ?? this.name,
        isExpanded: isExpanded ?? this.isExpanded,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'is_expanded': isExpanded,
  };

  factory HttpRequestGroup.fromJson(Map<String, dynamic> json) =>
      HttpRequestGroup(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Group',
        isExpanded: json['is_expanded'] as bool? ?? true,
      );
}

// ── HttpResponseResult ────────────────────────────────────────────────────────

/// The result of a completed HTTP request.
class HttpResponseResult {
  final int statusCode;

  /// Raw response body string.
  final String body;

  final Map<String, String> headers;

  /// Elapsed time from sending the request to receiving the full response.
  final int durationMs;

  const HttpResponseResult({
    required this.statusCode,
    required this.body,
    required this.headers,
    required this.durationMs,
  });

  /// Returns [body] pretty-printed if it is valid JSON, otherwise returns
  /// the raw string unchanged.
  String get prettyBody {
    try {
      final decoded = jsonDecode(body);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return body;
    }
  }

  /// Returns `true` for 2xx status codes.
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
