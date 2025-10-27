import 'package:mockondo/core/server.dart';

class MockData {
  int id;
  String name;
  String host;
  int port;
  List<MockModel> mockModels;
  MainServer? server;

  MockData({
    this.id = 0,
    required this.name,
    required this.host,
    required this.port,
    required this.mockModels,
    this.server,
  });

  MockData copyWith({
    int? id,
    String? name,
    String? host,
    int? port,
    List<MockModel>? mockModels,
    MainServer? server,
  }) {
    return MockData(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      mockModels: mockModels ?? this.mockModels,
      server: server ?? this.server,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'host': host,
      'port': port,
      'mock_models': mockModels.map((model) => model.toJson()).toList(),
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
      server: MainServer(),
    );
  }
}

class MockModel {
  bool enable;
  String endpoint;
  int statusCode;
  int? delay;
  Map<String, Object>? responseHeader;
  String responseBody;
  String method;
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

class Rules {
  RulesType type;
  Map<String, dynamic> rules;
  String response;

  Rules({required this.type, required this.rules, required this.response});

  Rules copyWith({
    RulesType? type,
    Map<String, dynamic>? rules,
    String? response,
  }) {
    return Rules(
      type: type ?? this.type,
      rules: rules ?? this.rules,
      response: response ?? this.response,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.toString().split('.').last,
      'rules': rules,
      'response': response,
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
    );
  }
}

enum RulesType { response, pagination, sorting, filtering, searching }
