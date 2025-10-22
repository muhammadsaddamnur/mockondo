class MockData {
  String host;
  int port;
  List<MockModel> mockModels;

  MockData({required this.host, required this.port, required this.mockModels});

  MockData copyWith({String? host, int? port, List<MockModel>? mockModels}) {
    return MockData(
      host: host ?? this.host,
      port: port ?? this.port,
      mockModels: mockModels ?? this.mockModels,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'mock_models': mockModels.map((model) => model.toJson()).toList(),
    };
  }

  factory MockData.fromJson(Map<String, dynamic> json) {
    return MockData(
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 8080,
      mockModels:
          (json['mock_models'] as List<dynamic>?)
              ?.map((e) => MockModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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

  MockModel({
    required this.enable,
    required this.endpoint,
    required this.statusCode,
    this.delay,
    this.responseHeader,
    required this.responseBody,
    required this.method,
  });

  MockModel copyWith({
    bool? enable,
    String? endpoint,
    int? statusCode,
    int? delay,
    Map<String, Object>? responseHeader,
    String? responseBody,
    String? method,
  }) {
    return MockModel(
      enable: enable ?? this.enable,
      endpoint: endpoint ?? this.endpoint,
      statusCode: statusCode ?? this.statusCode,
      delay: delay ?? this.delay,
      responseHeader: responseHeader ?? this.responseHeader,
      responseBody: responseBody ?? this.responseBody,
      method: method ?? this.method,
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
    );
  }
}

class Rules {}
