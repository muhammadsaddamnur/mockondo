import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart' hide Response;
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/prompt.dart';
import 'package:mockondo/core/routing_core.dart';
import 'package:mockondo/core/schema_service.dart';
import 'package:mockondo/core/server.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:mockondo/features/mock_s3/data/models/s3_model.dart';
import 'package:mockondo/features/mock_s3/presentation/controllers/mock_s3_controller.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/v4.dart';

/// The Remote Server is an optional HTTP control plane that lets external
/// tools (AI agents, CI/CD pipelines, scripts) interact with all Mockondo
/// features programmatically.
///
/// Enable it in Settings → Remote Server.
class RemoteServer {
  HttpServer? _httpServer;
  bool _isRunning = false;
  String _apiKey = '';

  bool get isRunning => _isRunning;

  // ── Helpers ──────────────────────────────────────────────────────────────

  Response _ok(dynamic data) => Response.ok(
    jsonEncode({'success': true, 'data': data}),
    headers: {'content-type': 'application/json'},
  );

  Response _error(int status, String message) => Response(
    status,
    body: jsonEncode({'success': false, 'message': message}),
    headers: {'content-type': 'application/json'},
  );

  Future<Map<String, dynamic>?> _parseBody(Request req) async {
    try {
      final body = await req.readAsString();
      if (body.isEmpty) return {};
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Returns null if auth passes; returns an error Response if it fails.
  Response? _checkAuth(Request req) {
    if (_apiKey.isEmpty) return null;
    final auth = req.headers['authorization'] ?? '';
    if (auth == 'Bearer $_apiKey') return null;
    return _error(401, 'Unauthorized');
  }

  HomeController get _home => Get.find<HomeController>();

  MockS3Controller? get _s3 =>
      Get.isRegistered<MockS3Controller>()
          ? Get.find<MockS3Controller>()
          : null;

  MockData? _findProject(String id) {
    final pid = int.tryParse(id);
    if (pid == null) return null;
    try {
      return _home.mockModels.firstWhere((m) => m?.id == pid);
    } catch (_) {
      return null;
    }
  }

  int _projectIndex(String id) {
    final pid = int.tryParse(id);
    if (pid == null) return -1;
    return _home.mockModels.indexWhere((m) => m?.id == pid);
  }

  Map<String, dynamic> _projectSummary(MockData p) => {
    'id': p.id,
    'name': p.name,
    'host': p.host,
    'port': p.port,
    'isRunning': p.server?.isRunning ?? false,
    'endpointCount': p.mockModels.length,
    'wsEndpointCount': p.wsMockModels.length,
  };

  Map<String, dynamic> _endpointToMap(int index, MockModel m) => {
    'index': index,
    'enable': m.enable,
    'endpoint': m.endpoint,
    'method': m.method,
    'statusCode': m.statusCode,
    'responseBody': m.responseBody,
    'delay': m.delay ?? 0,
    'responseHeader': m.responseHeader ?? {},
    'rules': (m.rules ?? []).map(_ruleToMap).toList(),
  };

  Map<String, dynamic> _ruleToMap(Rules r) {
    if (r.type == RulesType.pagination) {
      return {
        'isPagination': true,
        'type': r.type.name,
        'responseBody': r.response,
        'offsetParam': r.rules['offset_param'] ?? '',
        'limitParam': r.rules['limit_param'] ?? '',
        'max': r.rules['max'] ?? 0,
        'customLimit': r.rules['custom_limit'],
        'customOffset': r.rules['custom_offset'],
        'offsetType': r.rules['offset_type'],
      };
    }
    return {
      'id': r.rules['id'] ?? '',
      'type': r.type.name,
      'isPagination': false,
      'label': r.label,
      'statusCode': r.ruleStatusCode,
      'response': r.response,
      'responseHeader': r.responseHeader ?? {},
      'logic': r.logic.name,
      'conditions': r.conditions.map((c) => c.toJson()).toList(),
    };
  }

  Map<String, dynamic> _wsEndpointToMap(int index, WsMockModel ws) => {
    'index': index,
    'enable': ws.enable,
    'endpoint': ws.endpoint,
    'onConnectMessage': ws.onConnectMessage ?? '',
    'rules': ws.rules.map((r) => r.toJson()).toList(),
    'scheduledMessages': ws.scheduledMessages.map((s) => s.toJson()).toList(),
  };

  // ── Router ────────────────────────────────────────────────────────────────

  Handler _buildHandler() {
    final router = Router();

    // ── Status ──────────────────────────────────────────────────────────────
    router.get('/api/status', (Request req) {
      if (_checkAuth(req) case final err?) return err;
      final projects =
          _home.mockModels.whereType<MockData>().map(_projectSummary).toList();
      final s3 = _s3;
      return _ok({
        'remoteServerPort': _httpServer?.port,
        'projects': projects,
        's3':
            s3 == null
                ? null
                : {
                  'isRunning': s3.isRunning.value,
                  'host': s3.config.value.host,
                  'port': s3.config.value.port,
                },
      });
    });

    // ── Projects ─────────────────────────────────────────────────────────────

    router.get('/api/projects', (Request req) {
      if (_checkAuth(req) case final err?) return err;
      final list =
          _home.mockModels.whereType<MockData>().map(_projectSummary).toList();
      return _ok(list);
    });

    router.post('/api/projects', (Request req) async {
      if (_checkAuth(req) case final err?) return err;
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final name = body['name'] as String?;
      if (name == null || name.trim().isEmpty) {
        return _error(400, "Field 'name' is required");
      }
      final id =
          _home.mockModels.isNotEmpty ? _home.mockModels.last!.id + 1 : 1;
      final port = (body['port'] as int?) ?? (8080 + id);
      final host = (body['host'] as String?) ?? '';
      final project = MockData(
        id: id,
        name: name.trim(),
        host: host,
        port: port,
        mockModels: [],
        server: MainServer(),
      );
      _home.mockModels.add(project);
      await _home.save();
      return _ok(_projectSummary(project));
    });

    router.get('/api/projects/<id>', (Request req, String id) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');
      final map = _projectSummary(p);
      map['mockModels'] =
          p.mockModels
              .asMap()
              .entries
              .map((e) => _endpointToMap(e.key, e.value))
              .toList();
      map['wsMockModels'] =
          p.wsMockModels
              .asMap()
              .entries
              .map((e) => _wsEndpointToMap(e.key, e.value))
              .toList();
      return _ok(map);
    });

    router.put('/api/projects/<id>', (Request req, String id) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final p = _home.mockModels[idx]!;
      final wasRunning = p.server?.isRunning ?? false;
      if (wasRunning) p.server?.stop();
      final updated = p.copyWith(
        name: body['name'] as String? ?? p.name,
        host: body['host'] as String? ?? p.host,
        port: body['port'] as int? ?? p.port,
      );
      _home.mockModels[idx] = updated;
      if (wasRunning) {
        updated.server?.setPort = updated.port;
        await updated.server?.run();
      }
      await _home.save();
      return _ok(_projectSummary(updated));
    });

    router.delete('/api/projects/<id>', (Request req, String id) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      _home.mockModels[idx]?.server?.stop();
      _home.mockModels.removeAt(idx);
      await _home.save();
      return _ok(null);
    });

    router.post('/api/projects/<id>/start', (Request req, String id) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final p = _home.mockModels[idx]!;
      if (p.server?.isRunning ?? false) {
        return _ok(_projectSummary(p));
      }
      p.server?.clearRouters();
      p.server?.clearWsEndpoints();
      for (final m in p.mockModels) {
        if (!m.enable) continue;
        p.server?.addRouter(RoutingCore().getRouter(m.method, m));
      }
      for (final ws in p.wsMockModels) {
        if (!ws.enable) continue;
        p.server?.addWsEndpoint(ws);
      }
      p.server?.setPort = p.port;
      try {
        await p.server?.run();
      } catch (e) {
        return _error(500, 'Failed to start server: $e');
      }
      return _ok(_projectSummary(p));
    });

    router.post('/api/projects/<id>/stop', (Request req, String id) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final p = _home.mockModels[idx]!;
      p.server?.stop();
      return _ok({'id': p.id, 'isRunning': false});
    });

    // ── HTTP Endpoints ────────────────────────────────────────────────────────

    router.get('/api/projects/<id>/endpoints', (Request req, String id) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');
      return _ok(
        p.mockModels
            .asMap()
            .entries
            .map((e) => _endpointToMap(e.key, e.value))
            .toList(),
      );
    });

    router.post('/api/projects/<id>/endpoints', (Request req, String id) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final endpoint = body['endpoint'] as String?;
      final method = body['method'] as String?;
      if (endpoint == null || endpoint.trim().isEmpty) {
        return _error(400, "Field 'endpoint' is required");
      }
      if (method == null || method.trim().isEmpty) {
        return _error(400, "Field 'method' is required");
      }
      final m = MockModel(
        enable: body['enable'] as bool? ?? true,
        endpoint: endpoint.trim(),
        method: method.trim().toUpperCase(),
        statusCode: body['statusCode'] as int? ?? 200,
        responseBody: body['responseBody'] as String? ?? '',
        delay: body['delay'] as int? ?? 0,
        responseHeader: (body['responseHeader'] as Map<String, dynamic>?)?.map(
          (k, v) => MapEntry(k, v as Object),
        ),
      );
      _home.mockModels[idx]!.mockModels.add(m);
      await _home.save();
      final newIdx = _home.mockModels[idx]!.mockModels.length - 1;
      return _ok(_endpointToMap(newIdx, m));
    });

    router.get('/api/projects/<id>/endpoints/<eIdx>', (
      Request req,
      String id,
      String eIdx,
    ) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');
      final i = int.tryParse(eIdx);
      if (i == null || i < 0 || i >= p.mockModels.length) {
        return _error(404, 'Endpoint not found');
      }
      return _ok(_endpointToMap(i, p.mockModels[i]));
    });

    router.put('/api/projects/<id>/endpoints/<eIdx>', (
      Request req,
      String id,
      String eIdx,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final i = int.tryParse(eIdx);
      final p = _home.mockModels[idx]!;
      if (i == null || i < 0 || i >= p.mockModels.length) {
        return _error(404, 'Endpoint not found');
      }
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final old = p.mockModels[i];
      final updated = old.copyWith(
        enable: body['enable'] as bool? ?? old.enable,
        endpoint: body['endpoint'] as String? ?? old.endpoint,
        method: (body['method'] as String?)?.toUpperCase() ?? old.method,
        statusCode: body['statusCode'] as int? ?? old.statusCode,
        responseBody: body['responseBody'] as String? ?? old.responseBody,
        delay: body['delay'] as int? ?? old.delay,
        responseHeader:
            body.containsKey('responseHeader')
                ? (body['responseHeader'] as Map<String, dynamic>?)?.map(
                  (k, v) => MapEntry(k, v as Object),
                )
                : old.responseHeader,
      );
      p.mockModels[i] = updated;
      await _home.save();
      return _ok(_endpointToMap(i, updated));
    });

    router.delete('/api/projects/<id>/endpoints/<eIdx>', (
      Request req,
      String id,
      String eIdx,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final i = int.tryParse(eIdx);
      final p = _home.mockModels[idx]!;
      if (i == null || i < 0 || i >= p.mockModels.length) {
        return _error(404, 'Endpoint not found');
      }
      p.mockModels.removeAt(i);
      await _home.save();
      return _ok(null);
    });

    // ── Rules ─────────────────────────────────────────────────────────────────

    router.get('/api/projects/<id>/endpoints/<eIdx>/rules', (
      Request req,
      String id,
      String eIdx,
    ) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');
      final i = int.tryParse(eIdx);
      if (i == null || i < 0 || i >= p.mockModels.length) {
        return _error(404, 'Endpoint not found');
      }
      return _ok((p.mockModels[i].rules ?? []).map(_ruleToMap).toList());
    });

    router.post('/api/projects/<id>/endpoints/<eIdx>/rules', (
      Request req,
      String id,
      String eIdx,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final i = int.tryParse(eIdx);
      final p = _home.mockModels[idx]!;
      if (i == null || i < 0 || i >= p.mockModels.length) {
        return _error(404, 'Endpoint not found');
      }
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final isPagination = body['isPagination'] == true;

      final Rules rule;
      if (isPagination) {
        // Pagination rule: store pagination-specific fields.
        // Remove any existing pagination rule first (only one allowed).
        final allRules = p.mockModels[i].rules ?? [];
        allRules.removeWhere((r) => r.type == RulesType.pagination);
        p.mockModels[i].rules = allRules;

        rule = Rules(
          type: RulesType.pagination,
          response: body['responseBody'] as String? ?? '',
          rules: {
            'offset_param': body['offsetParam'] as String? ?? 'page',
            'limit_param': body['limitParam'] as String? ?? 'limit',
            'max': body['max'] as int? ?? 100,
            'custom_limit': body['customLimit'] as int?,
            'custom_offset': body['customOffset'] as int?,
            'offset_type': body['offsetType'] as String?,
          },
        );
      } else {
        // Response rule: store conditions and metadata.
        final ruleId = UuidV4().generate();
        final conditions =
            (body['conditions'] as List<dynamic>? ?? [])
                .map(
                  (c) => ResponseCondition.fromJson(c as Map<String, dynamic>),
                )
                .toList();
        rule = Rules(
          type: RulesType.response,
          response: body['responseBody'] as String? ?? '',
          rules: {
            'id': ruleId,
            'label': body['label'] as String? ?? '',
            'status_code': body['statusCode'] as int? ?? 200,
            'logic': body['logic'] as String? ?? 'and',
            'conditions': conditions.map((c) => c.toJson()).toList(),
          },
          responseHeader: (body['responseHeader'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v as Object)),
        );
      }
      final allRules = p.mockModels[i].rules ?? [];
      allRules.add(rule);
      p.mockModels[i].rules = allRules;
      await _home.save();
      return _ok(_ruleToMap(rule));
    });

    router.put('/api/projects/<id>/endpoints/<eIdx>/rules/<ruleId>', (
      Request req,
      String id,
      String eIdx,
      String ruleId,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final i = int.tryParse(eIdx);
      final p = _home.mockModels[idx]!;
      if (i == null || i < 0 || i >= p.mockModels.length) {
        return _error(404, 'Endpoint not found');
      }
      final allRules = p.mockModels[i].rules ?? [];
      final rIdx = allRules.indexWhere((r) => r.rules['id'] == ruleId);
      if (rIdx < 0) return _error(404, 'Rule not found');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final old = allRules[rIdx];

      final Rules updated;
      if (old.type == RulesType.pagination) {
        // Update pagination rule fields.
        updated = old.copyWith(
          response: body['responseBody'] as String? ?? old.response,
          rules: {
            ...old.rules,
            if (body.containsKey('offsetParam'))
              'offset_param': body['offsetParam'],
            if (body.containsKey('limitParam'))
              'limit_param': body['limitParam'],
            if (body.containsKey('max')) 'max': body['max'],
            if (body.containsKey('customLimit'))
              'custom_limit': body['customLimit'],
            if (body.containsKey('customOffset'))
              'custom_offset': body['customOffset'],
            if (body.containsKey('offsetType'))
              'offset_type': body['offsetType'],
          },
        );
      } else {
        // Update response rule fields.
        final conditions =
            body.containsKey('conditions')
                ? (body['conditions'] as List<dynamic>)
                    .map(
                      (c) =>
                          ResponseCondition.fromJson(c as Map<String, dynamic>),
                    )
                    .toList()
                : old.conditions;
        updated = old.copyWith(
          response: body['responseBody'] as String? ?? old.response,
          responseHeader:
              body.containsKey('responseHeader')
                  ? (body['responseHeader'] as Map<String, dynamic>?)?.map(
                    (k, v) => MapEntry(k, v as Object),
                  )
                  : old.responseHeader,
          rules: {
            ...old.rules,
            if (body.containsKey('label')) 'label': body['label'],
            if (body.containsKey('statusCode'))
              'status_code': body['statusCode'],
            if (body.containsKey('logic')) 'logic': body['logic'],
            'conditions': conditions.map((c) => c.toJson()).toList(),
          },
        );
      }
      allRules[rIdx] = updated;
      p.mockModels[i].rules = allRules;
      await _home.save();
      return _ok(_ruleToMap(updated));
    });

    router.delete('/api/projects/<id>/endpoints/<eIdx>/rules/<ruleId>', (
      Request req,
      String id,
      String eIdx,
      String ruleId,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final i = int.tryParse(eIdx);
      final p = _home.mockModels[idx]!;
      if (i == null || i < 0 || i >= p.mockModels.length) {
        return _error(404, 'Endpoint not found');
      }
      final allRules = p.mockModels[i].rules ?? [];
      final before = allRules.length;
      allRules.removeWhere((r) => r.rules['id'] == ruleId);
      if (allRules.length == before) return _error(404, 'Rule not found');
      p.mockModels[i].rules = allRules;
      await _home.save();
      return _ok(null);
    });

    // ── WebSocket Endpoints ───────────────────────────────────────────────────

    router.get('/api/projects/<id>/ws-endpoints', (Request req, String id) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');
      return _ok(
        p.wsMockModels
            .asMap()
            .entries
            .map((e) => _wsEndpointToMap(e.key, e.value))
            .toList(),
      );
    });

    router.post('/api/projects/<id>/ws-endpoints', (
      Request req,
      String id,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final endpoint = body['endpoint'] as String?;
      if (endpoint == null || endpoint.trim().isEmpty) {
        return _error(400, "Field 'endpoint' is required");
      }
      final rules =
          (body['rules'] as List<dynamic>? ?? [])
              .map((r) => WsMockRule.fromJson(r as Map<String, dynamic>))
              .toList();
      final scheduled =
          (body['scheduledMessages'] as List<dynamic>? ?? [])
              .map(
                (s) => WsScheduledMessage.fromJson(s as Map<String, dynamic>),
              )
              .toList();
      final ws = WsMockModel(
        enable: body['enable'] as bool? ?? true,
        endpoint: endpoint.trim(),
        onConnectMessage: body['onConnectMessage'] as String?,
        rules: rules,
        scheduledMessages: scheduled,
      );
      _home.mockModels[idx]!.wsMockModels.add(ws);
      await _home.save();
      final newIdx = _home.mockModels[idx]!.wsMockModels.length - 1;
      return _ok(_wsEndpointToMap(newIdx, ws));
    });

    router.get('/api/projects/<id>/ws-endpoints/<wsIdx>', (
      Request req,
      String id,
      String wsIdx,
    ) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');
      final i = int.tryParse(wsIdx);
      if (i == null || i < 0 || i >= p.wsMockModels.length) {
        return _error(404, 'WebSocket endpoint not found');
      }
      return _ok(_wsEndpointToMap(i, p.wsMockModels[i]));
    });

    router.put('/api/projects/<id>/ws-endpoints/<wsIdx>', (
      Request req,
      String id,
      String wsIdx,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final i = int.tryParse(wsIdx);
      final p = _home.mockModels[idx]!;
      if (i == null || i < 0 || i >= p.wsMockModels.length) {
        return _error(404, 'WebSocket endpoint not found');
      }
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final old = p.wsMockModels[i];
      final rules =
          body.containsKey('rules')
              ? (body['rules'] as List<dynamic>)
                  .map((r) => WsMockRule.fromJson(r as Map<String, dynamic>))
                  .toList()
              : old.rules;
      final scheduled =
          body.containsKey('scheduledMessages')
              ? (body['scheduledMessages'] as List<dynamic>)
                  .map(
                    (s) =>
                        WsScheduledMessage.fromJson(s as Map<String, dynamic>),
                  )
                  .toList()
              : old.scheduledMessages;
      final updated = old.copyWith(
        enable: body['enable'] as bool? ?? old.enable,
        endpoint: body['endpoint'] as String? ?? old.endpoint,
        onConnectMessage:
            body['onConnectMessage'] as String? ?? old.onConnectMessage,
        rules: rules,
        scheduledMessages: scheduled,
      );
      p.wsMockModels[i] = updated;
      await _home.save();
      return _ok(_wsEndpointToMap(i, updated));
    });

    router.delete('/api/projects/<id>/ws-endpoints/<wsIdx>', (
      Request req,
      String id,
      String wsIdx,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final i = int.tryParse(wsIdx);
      final p = _home.mockModels[idx]!;
      if (i == null || i < 0 || i >= p.wsMockModels.length) {
        return _error(404, 'WebSocket endpoint not found');
      }
      p.wsMockModels.removeAt(i);
      await _home.save();
      return _ok(null);
    });

    // ── Custom Data ───────────────────────────────────────────────────────────

    router.get('/api/custom-data', (Request req) {
      if (_checkAuth(req) case final err?) return err;
      return _ok(_home.customData.map((k, v) => MapEntry(k, v.toList())));
    });

    router.get('/api/custom-data/<key>', (Request req, String key) {
      if (_checkAuth(req) case final err?) return err;
      if (!_home.customData.containsKey(key)) {
        return _error(404, 'Custom data key not found');
      }
      return _ok(_home.customData[key]!.toList());
    });

    router.post('/api/custom-data/<key>', (Request req, String key) async {
      if (_checkAuth(req) case final err?) return err;
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final values = body['values'];
      if (values == null || values is! List) {
        return _error(400, "Field 'values' must be an array");
      }
      _home.customData[key] = RxList<String>.from(
        values.map((v) => v.toString()),
      );
      await _home.saveCustomData();
      return _ok({'key': key, 'values': _home.customData[key]!.toList()});
    });

    router.patch('/api/custom-data/<key>', (Request req, String key) async {
      if (_checkAuth(req) case final err?) return err;
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final values = body['values'];
      if (values == null || values is! List) {
        return _error(400, "Field 'values' must be an array");
      }
      if (!_home.customData.containsKey(key)) {
        _home.customData[key] = RxList<String>();
      }
      _home.customData[key]!.addAll(values.map((v) => v.toString()));
      await _home.saveCustomData();
      return _ok({'key': key, 'values': _home.customData[key]!.toList()});
    });

    router.delete('/api/custom-data/<key>', (Request req, String key) async {
      if (_checkAuth(req) case final err?) return err;
      if (!_home.customData.containsKey(key)) {
        return _error(404, 'Custom data key not found');
      }
      _home.customData.remove(key);
      await _home.saveCustomData();
      return _ok(null);
    });

    // ── Mock S3 ───────────────────────────────────────────────────────────────

    router.get('/api/s3/config', (Request req) {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      final c = s3.config.value;
      return _ok({
        'host': c.host,
        'port': c.port,
        'accessKeyId': c.accessKey,
        'secretAccessKey': c.secretKey,
        'region': c.region,
        'isRunning': s3.isRunning.value,
      });
    });

    router.put('/api/s3/config', (Request req) async {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final old = s3.config.value;
      final updated = S3Config(
        host: body['host'] as String? ?? old.host,
        port: body['port'] as int? ?? old.port,
        accessKey: body['accessKeyId'] as String? ?? old.accessKey,
        secretKey: body['secretAccessKey'] as String? ?? old.secretKey,
        region: body['region'] as String? ?? old.region,
      );
      final wasRunning = s3.isRunning.value;
      if (wasRunning) await s3.stopServer();
      s3.updateConfig(updated);
      if (wasRunning) await s3.startServer();
      return _ok({
        'host': updated.host,
        'port': updated.port,
        'accessKeyId': updated.accessKey,
        'secretAccessKey': updated.secretKey,
        'region': updated.region,
        'isRunning': s3.isRunning.value,
      });
    });

    router.post('/api/s3/start', (Request req) async {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      try {
        await s3.startServer();
      } catch (e) {
        return _error(500, 'Failed to start S3 server: $e');
      }
      return _ok({
        'isRunning': s3.isRunning.value,
        'host': s3.config.value.host,
        'port': s3.config.value.port,
      });
    });

    router.post('/api/s3/stop', (Request req) async {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      await s3.stopServer();
      return _ok({'isRunning': false});
    });

    router.get('/api/s3/buckets', (Request req) {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      return _ok(s3.buckets.map((b) => b.toJson()).toList());
    });

    router.post('/api/s3/buckets', (Request req) async {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final name = body['name'] as String?;
      if (name == null || name.trim().isEmpty) {
        return _error(400, "Field 'name' is required");
      }
      s3.createBucket(name.trim());
      final bucket = s3.buckets.firstWhere((b) => b.name == name.trim());
      return _ok(bucket.toJson());
    });

    router.delete('/api/s3/buckets/<bucket>', (
      Request req,
      String bucket,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      await s3.deleteBucket(bucket);
      return _ok(null);
    });

    router.get('/api/s3/objects/<bucket>', (Request req, String bucket) {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      final prefix = req.url.queryParameters['prefix'] ?? '';
      final objects =
          s3.objects
              .where(
                (o) =>
                    o.bucket == bucket &&
                    (prefix.isEmpty || o.key.startsWith(prefix)),
              )
              .map((o) => o.toJson())
              .toList();
      return _ok(objects);
    });

    router.delete('/api/s3/objects/<bucket>/<key>', (
      Request req,
      String bucket,
      String key,
    ) async {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      final obj = s3.objects.firstWhereOrNull(
        (o) => o.bucket == bucket && o.key == key,
      );
      if (obj == null) return _error(404, 'Object not found');
      await s3.deleteObject(obj);
      return _ok(null);
    });

    router.post('/api/s3/presign', (Request req) async {
      if (_checkAuth(req) case final err?) return err;
      final s3 = _s3;
      if (s3 == null) return _error(404, 'S3 controller not available');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final bucket = body['bucket'] as String?;
      final key = body['key'] as String?;
      final operation = (body['operation'] as String?)?.toUpperCase();
      final expirySeconds = body['expirySeconds'] as int? ?? 3600;
      if (bucket == null || bucket.isEmpty) {
        return _error(400, "Field 'bucket' is required");
      }
      if (key == null || key.isEmpty) {
        return _error(400, "Field 'key' is required");
      }
      if (operation != 'GET' && operation != 'PUT') {
        return _error(400, "Field 'operation' must be 'GET' or 'PUT'");
      }
      final c = s3.config.value;
      final uri = 'http://${c.host}:${c.port}';
      final result = s3.generatePresignedUrl(
        bucket: bucket,
        key: key,
        operation: operation!,
        expirySeconds: expirySeconds,
        uri: uri,
      );
      return _ok({
        'url': result.url,
        'operation': result.operation,
        'bucket': result.bucket,
        'key': result.key,
        'token': result.token,
        'expiresAt': result.expiresAt.toIso8601String(),
      });
    });

    // ── OpenAPI / AsyncAPI export ─────────────────────────────────────────────

    router.get('/api/projects/<id>/export/openapi', (Request req, String id) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');
      final spec = SchemaService.buildOpenApiSpec(p);
      return _ok(spec);
    });

    router.get('/api/projects/<id>/export/asyncapi', (Request req, String id) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');
      final spec = SchemaService.buildAsyncApiSpec(p);
      return _ok(spec);
    });

    // ── OpenAPI / AsyncAPI import ─────────────────────────────────────────────

    router.post('/api/projects/<id>/import/openapi',
        (Request req, String id) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final specJson = body['spec'];
      if (specJson == null) return _error(400, "Field 'spec' is required");
      try {
        final specStr = specJson is String
            ? specJson
            : jsonEncode(specJson);
        final endpoints = SchemaService.parseOpenApiSpec(specStr);
        _home.mockModels[idx]!.mockModels.addAll(endpoints);
        await _home.save();
        return _ok({
          'imported': endpoints.length,
          'endpoints': endpoints
              .asMap()
              .entries
              .map((e) => _endpointToMap(
                    _home.mockModels[idx]!.mockModels.length - endpoints.length + e.key,
                    e.value,
                  ))
              .toList(),
        });
      } on FormatException catch (e) {
        return _error(400, e.message);
      }
    });

    router.post('/api/projects/<id>/import/asyncapi',
        (Request req, String id) async {
      if (_checkAuth(req) case final err?) return err;
      final idx = _projectIndex(id);
      if (idx < 0) return _error(404, 'Project not found');
      final body = await _parseBody(req);
      if (body == null) return _error(400, 'Invalid request body');
      final specJson = body['spec'];
      if (specJson == null) return _error(400, "Field 'spec' is required");
      try {
        final specStr = specJson is String
            ? specJson
            : jsonEncode(specJson);
        final wsEndpoints = SchemaService.parseAsyncApiSpec(specStr);
        _home.mockModels[idx]!.wsMockModels.addAll(wsEndpoints);
        await _home.save();
        return _ok({
          'imported': wsEndpoints.length,
          'wsEndpoints': wsEndpoints
              .asMap()
              .entries
              .map((e) => _wsEndpointToMap(
                    _home.mockModels[idx]!.wsMockModels.length - wsEndpoints.length + e.key,
                    e.value,
                  ))
              .toList(),
        });
      } on FormatException catch (e) {
        return _error(400, e.message);
      }
    });

    // ── Schema to Code prompt ─────────────────────────────────────────────────

    router.get('/api/projects/<id>/schema-to-code-prompt',
        (Request req, String id) {
      if (_checkAuth(req) case final err?) return err;
      final p = _findProject(id);
      if (p == null) return _error(404, 'Project not found');

      final openApiSpec = SchemaService.buildOpenApiSpec(p);
      final asyncApiSpec = SchemaService.buildAsyncApiSpec(p);

      final lang = req.url.queryParameters['lang'] ?? 'auto';
      final dbDialect = req.url.queryParameters['db'] ?? 'postgresql';

      return _ok({
        'projectName': p.name,
        'language': lang,
        'dbDialect': dbDialect,
        'openApiSpec': openApiSpec,
        'asyncApiSpec': asyncApiSpec,
        'prompt': _buildSchemaToCodePrompt(
          project: p,
          openApiSpec: openApiSpec,
          asyncApiSpec: asyncApiSpec,
          lang: lang,
          dbDialect: dbDialect,
        ),
      });
    });

    // ── Agent Prompt ─────────────────────────────────────────────────────────

    router.get('/api/agent-prompt', (Request req) {
      if (_checkAuth(req) case final err?) return err;

      // Gather live state so the agent knows current port / projects
      final currentPort = _httpServer?.port ?? 3131;
      final projects =
          _home.mockModels.whereType<MockData>().map(_projectSummary).toList();

      return _ok(Prompt.agentPrompt(currentPort: currentPort, projects: projects, apiKey: _apiKey));
    });

    // ── Export ────────────────────────────────────────────────────────────────

    router.get('/api/export', (Request req) {
      if (_checkAuth(req) case final err?) return err;
      final projects =
          _home.mockModels
              .whereType<MockData>()
              .map((p) => p.toJson())
              .toList();
      final customData = _home.customData.map(
        (k, v) => MapEntry(k, v.toList()),
      );
      final s3 = _s3;
      return _ok({
        'version': 1,
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'mockProjects': projects,
        'customData': customData,
        's3Config': s3?.config.value.toJson(),
        's3Buckets': s3?.buckets.map((b) => b.toJson()).toList(),
        's3Objects': s3?.objects.map((o) => o.toJson()).toList(),
      });
    });

    return Pipeline()
        .addMiddleware(_errorMiddleware())
        .addMiddleware(_corsMiddleware())
        .addHandler(router.call);
  }

  Middleware _errorMiddleware() {
    return (Handler innerHandler) {
      return (Request req) async {
        try {
          return await innerHandler(req);
        } catch (e, st) {
          return Response.internalServerError(
            body: jsonEncode({
              'success': false,
              'message': 'Internal error: $e',
              'stackTrace': st.toString().split('\n').take(8).join('\n'),
            }),
            headers: {'content-type': 'application/json'},
          );
        }
      };
    };
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request req) async {
        if (req.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders());
        }
        final response = await innerHandler(req);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  String _buildSchemaToCodePrompt({
    required MockData project,
    required Map<String, dynamic> openApiSpec,
    required Map<String, dynamic> asyncApiSpec,
    required String lang,
    required String dbDialect,
  }) {
    final hasHttp = project.mockModels.isNotEmpty;
    final hasWs = project.wsMockModels.isNotEmpty;
    final langLabel = lang == 'auto' ? 'the most suitable language' : lang;
    final dbLabel = dbDialect;

    final buf = StringBuffer();
    buf.writeln(
      'You are a senior software engineer. Using the API specifications below, generate production-ready backend code and a database schema.',
    );
    buf.writeln();
    buf.writeln('## Project: ${project.name}');
    buf.writeln('Language: $langLabel');
    buf.writeln('Database: $dbLabel');
    buf.writeln();
    buf.writeln('## Instructions');
    buf.writeln(
      '1. Analyse the OpenAPI spec (HTTP endpoints) and AsyncAPI spec (WebSocket channels) provided below.',
    );
    buf.writeln(
      '2. Generate a **database schema** ($dbLabel SQL):',
    );
    buf.writeln('   - Infer tables, columns, and types from the response body examples in the specs.');
    buf.writeln('   - Add primary keys, foreign keys, indexes, and constraints where appropriate.');
    buf.writeln('   - Include `created_at` / `updated_at` timestamps on every table.');
    buf.writeln();
    buf.writeln('3. Generate **backend source code** ($langLabel):');
    buf.writeln('   - Implement every HTTP endpoint from the OpenAPI spec (CRUD, auth, etc.).');
    if (hasWs) {
      buf.writeln('   - Implement every WebSocket channel from the AsyncAPI spec.');
    }
    buf.writeln('   - Use the response body examples as the shape of your DTOs / models.');
    buf.writeln('   - Follow REST best practices: proper status codes, error responses, input validation.');
    buf.writeln('   - Include a brief setup/run section in comments at the top of each file.');
    buf.writeln();
    buf.writeln('4. Output format:');
    buf.writeln('   - SQL file first, clearly labelled.');
    buf.writeln('   - Then each source file, clearly labelled with its filename.');
    buf.writeln('   - Keep code clean and idiomatic for $langLabel.');
    buf.writeln();

    if (hasHttp) {
      buf.writeln('## OpenAPI 3.0 Spec (HTTP Endpoints)');
      buf.writeln('```json');
      buf.writeln(const JsonEncoder.withIndent('  ').convert(openApiSpec));
      buf.writeln('```');
      buf.writeln();
    }

    if (hasWs) {
      buf.writeln('## AsyncAPI 2.6 Spec (WebSocket Channels)');
      buf.writeln('```json');
      buf.writeln(const JsonEncoder.withIndent('  ').convert(asyncApiSpec));
      buf.writeln('```');
      buf.writeln();
    }

    if (!hasHttp && !hasWs) {
      buf.writeln('_(No endpoints defined yet in this project.)_');
    }

    return buf.toString();
  }

  Map<String, String> _corsHeaders() => {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  };

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> start(int port, {String apiKey = ''}) async {
    if (_isRunning) await stop();
    _apiKey = apiKey;
    _httpServer = await serve(
      _buildHandler(),
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    _isRunning = true;
  }

  Future<void> stop() async {
    await _httpServer?.close(force: true);
    _httpServer = null;
    _isRunning = false;
  }
}
