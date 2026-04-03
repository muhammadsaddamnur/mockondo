import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:mockondo/core/colors.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:uuid/v4.dart';

/// Handles per-project OpenAPI 3.0 (HTTP) and AsyncAPI 2.6 (WebSocket)
/// import/export.
class SchemaService {
  SchemaService._();

  // ── Pure spec builders / parsers (no BuildContext, no file I/O) ─────────

  /// Builds an OpenAPI 3.0.3 spec map from [project] without any file I/O.
  static Map<String, dynamic> buildOpenApiSpec(MockData project) {
    final paths = <String, dynamic>{};
    for (final m in project.mockModels) {
      final pathKey = m.endpoint.isEmpty ? '/' : m.endpoint;
      paths.putIfAbsent(pathKey, () => <String, dynamic>{});
      dynamic bodyExample;
      try {
        bodyExample = m.responseBody.trim().isNotEmpty
            ? jsonDecode(m.responseBody)
            : null;
      } catch (_) {
        bodyExample = m.responseBody.trim().isNotEmpty ? m.responseBody : null;
      }
      final responseHeaders = <String, dynamic>{};
      m.responseHeader?.forEach((k, v) {
        responseHeaders[k] = {'schema': {'type': 'string'}, 'example': v};
      });
      final responseContent = bodyExample != null
          ? {'application/json': {'example': bodyExample}}
          : null;
      final response = <String, dynamic>{
        'description': _statusDescription(m.statusCode),
        if (responseContent != null) 'content': responseContent,
        if (responseHeaders.isNotEmpty) 'headers': responseHeaders,
      };
      final rulesExt = (m.rules ?? []).map((r) => r.toJson()).toList();
      (paths[pathKey] as Map<String, dynamic>)[m.method.toLowerCase()] = {
        'summary': '${m.method} ${m.endpoint}',
        'responses': {'${m.statusCode}': response},
        'x-mockondo-enable': m.enable,
        if (m.delay != null && m.delay! > 0) 'x-mockondo-delay': m.delay,
        if (rulesExt.isNotEmpty) 'x-mockondo-rules': rulesExt,
      };
    }
    return {
      'openapi': '3.0.3',
      'info': {
        'title': project.name,
        'description': 'Exported from Mockondo',
        'version': '1.0.0',
      },
      'servers': [
        {'url': '${project.host.isNotEmpty ? project.host : 'localhost'}:${project.port}'},
      ],
      'paths': paths,
    };
  }

  /// Builds an AsyncAPI 2.6.0 spec map from [project] without any file I/O.
  static Map<String, dynamic> buildAsyncApiSpec(MockData project) {
    final channels = <String, dynamic>{};
    for (final ws in project.wsMockModels) {
      final channelKey = ws.endpoint.isEmpty ? '/ws' : ws.endpoint;
      final messages = ws.rules.map((r) => {
        'name': r.pattern,
        'payload': {'type': 'string', 'example': r.response},
        'x-mockondo-pattern': r.pattern,
        'x-mockondo-is-regex': r.isRegex,
      }).toList();
      channels[channelKey] = {
        'description': 'WebSocket endpoint',
        'subscribe': {
          'description': 'Messages sent by the server to clients',
          'message': messages.length == 1 ? messages.first : {'oneOf': messages},
        },
        'publish': {
          'description': 'Messages received from clients',
          'message': {'payload': {'type': 'string'}},
        },
        'x-mockondo-enable': ws.enable,
        if (ws.onConnectMessage != null && ws.onConnectMessage!.isNotEmpty)
          'x-mockondo-on-connect': ws.onConnectMessage,
        if (ws.rules.isNotEmpty)
          'x-mockondo-rules': ws.rules.map((r) => r.toJson()).toList(),
        if (ws.scheduledMessages.isNotEmpty)
          'x-mockondo-scheduled-messages':
              ws.scheduledMessages.map((s) => s.toJson()).toList(),
      };
    }
    return {
      'asyncapi': '2.6.0',
      'info': {
        'title': project.name,
        'description': 'Exported from Mockondo',
        'version': '1.0.0',
      },
      'servers': {
        'mock': {
          'url': '${project.host.isNotEmpty ? project.host : 'localhost'}:${project.port}',
          'protocol': 'ws',
        },
      },
      'channels': channels,
    };
  }

  /// Parses an OpenAPI 3.0 JSON string and returns [MockModel] list.
  /// Throws on invalid JSON or unsupported version.
  static List<MockModel> parseOpenApiSpec(String rawJson) {
    final raw = _decodeInterp(rawJson);
    final spec = jsonDecode(raw) as Map<String, dynamic>;
    final version = spec['openapi'] as String? ?? '';
    if (!version.startsWith('3.')) {
      throw FormatException('Only OpenAPI 3.x is supported (got "$version")');
    }
    final endpoints = <MockModel>[];
    final paths = spec['paths'] as Map<String, dynamic>? ?? {};
    for (final pathEntry in paths.entries) {
      final path = pathEntry.key;
      final methods = pathEntry.value as Map<String, dynamic>? ?? {};
      for (final methodEntry in methods.entries) {
        final method = methodEntry.key.toUpperCase();
        if (!{'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method)) continue;
        final op = methodEntry.value as Map<String, dynamic>? ?? {};
        final responses = op['responses'] as Map<String, dynamic>? ?? {};
        int statusCode = 200;
        String responseBody = '';
        Map<String, Object>? responseHeader;
        if (responses.isNotEmpty) {
          final firstCode = responses.keys.first;
          statusCode = int.tryParse(firstCode) ?? 200;
          final resp = responses[firstCode] as Map<String, dynamic>? ?? {};
          final content = resp['content'] as Map<String, dynamic>?;
          if (content != null) {
            final firstContent = content.values.first as Map<String, dynamic>?;
            final example = firstContent?['example'];
            if (example != null) {
              responseBody = example is String
                  ? example
                  : const JsonEncoder.withIndent('  ').convert(example);
            }
          }
          final headers = resp['headers'] as Map<String, dynamic>?;
          if (headers != null) {
            responseHeader = {};
            headers.forEach((k, v) {
              final hMap = v as Map<String, dynamic>? ?? {};
              final example = hMap['example'];
              if (example != null) responseHeader![k] = example as Object;
            });
            if (responseHeader.isEmpty) responseHeader = null;
          }
        }
        endpoints.add(MockModel(
          enable: op['x-mockondo-enable'] as bool? ?? false,
          endpoint: path,
          statusCode: statusCode,
          delay: op['x-mockondo-delay'] as int?,
          responseHeader: responseHeader,
          responseBody: responseBody,
          method: method,
          rules: (op['x-mockondo-rules'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map(Rules.fromJson)
              .toList(),
        ));
      }
    }
    return endpoints;
  }

  /// Parses an AsyncAPI 2.x JSON string and returns [WsMockModel] list.
  /// Throws on invalid JSON or unsupported version.
  static List<WsMockModel> parseAsyncApiSpec(String rawJson) {
    final raw = _decodeInterp(rawJson);
    final spec = jsonDecode(raw) as Map<String, dynamic>;
    final version = spec['asyncapi'] as String? ?? '';
    if (!version.startsWith('2.')) {
      throw FormatException('Only AsyncAPI 2.x is supported (got "$version")');
    }
    final wsModels = <WsMockModel>[];
    final channels = spec['channels'] as Map<String, dynamic>? ?? {};
    for (final entry in channels.entries) {
      final path = entry.key;
      final channel = entry.value as Map<String, dynamic>? ?? {};
      List<WsMockRule> rules = [];
      final rulesJson = channel['x-mockondo-rules'] as List<dynamic>?;
      if (rulesJson != null) {
        rules = rulesJson
            .whereType<Map<String, dynamic>>()
            .map(WsMockRule.fromJson)
            .toList();
      } else {
        final sub = channel['subscribe'] as Map<String, dynamic>?;
        final msg = sub?['message'] as Map<String, dynamic>?;
        if (msg != null) {
          final oneOf = msg['oneOf'] as List<dynamic>?;
          final messagesToParse =
              oneOf != null ? oneOf.cast<Map<String, dynamic>>() : [msg];
          for (final m in messagesToParse) {
            final pattern =
                m['x-mockondo-pattern'] as String? ?? m['name'] as String? ?? '';
            final isRegex = m['x-mockondo-is-regex'] as bool? ?? false;
            final payload = m['payload'] as Map<String, dynamic>? ?? {};
            final response = payload['example']?.toString() ?? '';
            if (pattern.isNotEmpty) {
              rules.add(WsMockRule(
                id: UuidV4().generate(),
                pattern: pattern,
                isRegex: isRegex,
                response: response,
              ));
            }
          }
        }
      }
      List<WsScheduledMessage> scheduled = [];
      final schedJson = channel['x-mockondo-scheduled-messages'] as List<dynamic>?;
      if (schedJson != null) {
        scheduled = schedJson
            .whereType<Map<String, dynamic>>()
            .map(WsScheduledMessage.fromJson)
            .toList();
      }
      wsModels.add(WsMockModel(
        enable: channel['x-mockondo-enable'] as bool? ?? false,
        endpoint: path,
        onConnectMessage: channel['x-mockondo-on-connect'] as String?,
        rules: rules,
        scheduledMessages: scheduled,
      ));
    }
    return wsModels;
  }

  // ── OpenAPI 3.0 export (HTTP endpoints) ──────────────────────────────────

  static Future<void> exportOpenApi(
    BuildContext context,
    MockData project,
  ) async {
    try {
      final paths = <String, dynamic>{};

      for (final m in project.mockModels) {
        final pathKey = m.endpoint.isEmpty ? '/' : m.endpoint;
        paths.putIfAbsent(pathKey, () => <String, dynamic>{});

        dynamic bodyExample;
        try {
          bodyExample = m.responseBody.trim().isNotEmpty
              ? jsonDecode(m.responseBody)
              : null;
        } catch (_) {
          bodyExample = m.responseBody.trim().isNotEmpty ? m.responseBody : null;
        }

        final responseHeaders = <String, dynamic>{};
        m.responseHeader?.forEach((k, v) {
          responseHeaders[k] = {
            'schema': {'type': 'string'},
            'example': v,
          };
        });

        final responseContent = bodyExample != null
            ? {
                'application/json': {
                  'example': bodyExample,
                }
              }
            : null;

        final response = <String, dynamic>{
          'description': _statusDescription(m.statusCode),
          if (responseContent != null) 'content': responseContent,
          if (responseHeaders.isNotEmpty) 'headers': responseHeaders,
        };

        // Build rules extension (Mockondo-specific)
        final rulesExt = (m.rules ?? [])
            .map((r) => r.toJson())
            .toList();

        final operation = <String, dynamic>{
          'summary': '${m.method} ${m.endpoint}',
          'responses': {
            '${m.statusCode}': response,
          },
          'x-mockondo-enable': m.enable,
          if (m.delay != null && m.delay! > 0) 'x-mockondo-delay': m.delay,
          if (rulesExt.isNotEmpty) 'x-mockondo-rules': rulesExt,
        };

        (paths[pathKey] as Map<String, dynamic>)[m.method.toLowerCase()] =
            operation;
      }

      final spec = {
        'openapi': '3.0.3',
        'info': {
          'title': project.name,
          'description': 'Exported from Mockondo',
          'version': '1.0.0',
        },
        'servers': [
          {
            'url': '${project.host.isNotEmpty ? project.host : 'localhost'}:${project.port}',
          }
        ],
        'paths': paths,
      };

      final jsonString = _encodeInterp(
          const JsonEncoder.withIndent('  ').convert(spec));

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export OpenAPI spec',
        fileName: '${_slug(project.name)}_openapi.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (savePath == null) return;

      await File(savePath).writeAsString(jsonString, flush: true);

      if (context.mounted) {
        _snack(context, '✅ OpenAPI exported to $savePath', success: true);
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, '❌ OpenAPI export failed: $e', success: false);
      }
    }
  }

  // ── OpenAPI 3.0 import (HTTP endpoints) ──────────────────────────────────

  /// Parses an OpenAPI 3.0 JSON file and returns new [MockModel] entries.
  /// Returns `null` if the user cancelled or parsing failed.
  static Future<List<MockModel>?> importOpenApi(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import OpenAPI spec',
        type: FileType.custom,
        allowedExtensions: ['json', 'yaml'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final filePath = result.files.single.path;
      if (filePath == null) return null;

      final raw = _decodeInterp(await File(filePath).readAsString());
      final Map<String, dynamic> spec =
          jsonDecode(raw) as Map<String, dynamic>;

      // Basic version check
      final version = spec['openapi'] as String? ?? '';
      if (!version.startsWith('3.')) {
        if (context.mounted) {
          _snack(
            context,
            '❌ Only OpenAPI 3.x files are supported.',
            success: false,
          );
        }
        return null;
      }

      final endpoints = <MockModel>[];
      final paths = spec['paths'] as Map<String, dynamic>? ?? {};

      for (final pathEntry in paths.entries) {
        final path = pathEntry.key;
        final methods = pathEntry.value as Map<String, dynamic>? ?? {};

        for (final methodEntry in methods.entries) {
          final method = methodEntry.key.toUpperCase();
          if (!{'GET', 'POST', 'PUT', 'PATCH', 'DELETE'}.contains(method)) {
            continue;
          }

          final op = methodEntry.value as Map<String, dynamic>? ?? {};
          final responses = op['responses'] as Map<String, dynamic>? ?? {};

          // Pick the first response code
          int statusCode = 200;
          String responseBody = '';
          Map<String, Object>? responseHeader;

          if (responses.isNotEmpty) {
            final firstCode = responses.keys.first;
            statusCode = int.tryParse(firstCode) ?? 200;

            final resp = responses[firstCode] as Map<String, dynamic>? ?? {};

            // Extract body example
            final content = resp['content'] as Map<String, dynamic>?;
            if (content != null) {
              final firstContent = content.values.first as Map<String, dynamic>?;
              final example = firstContent?['example'];
              if (example != null) {
                responseBody = example is String
                    ? example
                    : const JsonEncoder.withIndent('  ').convert(example);
              }
            }

            // Extract headers
            final headers =
                resp['headers'] as Map<String, dynamic>?;
            if (headers != null) {
              responseHeader = {};
              headers.forEach((k, v) {
                final hMap = v as Map<String, dynamic>? ?? {};
                final example = hMap['example'];
                if (example != null) {
                  responseHeader![k] = example as Object;
                }
              });
              if (responseHeader.isEmpty) responseHeader = null;
            }
          }

          final enable = op['x-mockondo-enable'] as bool? ?? false;
          final delay = op['x-mockondo-delay'] as int?;
          final rulesJson =
              op['x-mockondo-rules'] as List<dynamic>?;
          final rules = rulesJson
              ?.whereType<Map<String, dynamic>>()
              .map(Rules.fromJson)
              .toList();

          endpoints.add(MockModel(
            enable: enable,
            endpoint: path,
            statusCode: statusCode,
            delay: delay,
            responseHeader: responseHeader,
            responseBody: responseBody,
            method: method,
            rules: rules,
          ));
        }
      }

      if (context.mounted) {
        _snack(
          context,
          '✅ Imported ${endpoints.length} endpoint(s) from OpenAPI spec',
          success: true,
        );
      }
      return endpoints;
    } catch (e) {
      if (context.mounted) {
        _snack(context, '❌ OpenAPI import failed: $e', success: false);
      }
      return null;
    }
  }

  // ── AsyncAPI 2.6 export (WebSocket endpoints) ─────────────────────────────

  static Future<void> exportAsyncApi(
    BuildContext context,
    MockData project,
  ) async {
    try {
      final channels = <String, dynamic>{};

      for (final ws in project.wsMockModels) {
        final channelKey =
            ws.endpoint.isEmpty ? '/ws' : ws.endpoint;

        // Build message examples from rules
        final messages = ws.rules.map((r) {
          return {
            'name': r.pattern,
            'payload': {'type': 'string', 'example': r.response},
            'x-mockondo-pattern': r.pattern,
            'x-mockondo-is-regex': r.isRegex,
          };
        }).toList();

        channels[channelKey] = {
          'description': 'WebSocket endpoint',
          'subscribe': {
            'description': 'Messages sent by the server to clients',
            'message':
                messages.length == 1
                    ? messages.first
                    : {'oneOf': messages},
          },
          'publish': {
            'description': 'Messages received from clients',
            'message': {
              'payload': {'type': 'string'},
            },
          },
          'x-mockondo-enable': ws.enable,
          if (ws.onConnectMessage != null &&
              ws.onConnectMessage!.isNotEmpty)
            'x-mockondo-on-connect': ws.onConnectMessage,
          if (ws.rules.isNotEmpty)
            'x-mockondo-rules':
                ws.rules.map((r) => r.toJson()).toList(),
          if (ws.scheduledMessages.isNotEmpty)
            'x-mockondo-scheduled-messages':
                ws.scheduledMessages.map((s) => s.toJson()).toList(),
        };
      }

      final spec = {
        'asyncapi': '2.6.0',
        'info': {
          'title': project.name,
          'description': 'Exported from Mockondo',
          'version': '1.0.0',
        },
        'servers': {
          'mock': {
            'url': '${project.host.isNotEmpty ? project.host : 'localhost'}:${project.port}',
            'protocol': 'ws',
          }
        },
        'channels': channels,
      };

      final jsonString = _encodeInterp(
          const JsonEncoder.withIndent('  ').convert(spec));

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Export AsyncAPI spec',
        fileName: '${_slug(project.name)}_asyncapi.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (savePath == null) return;

      await File(savePath).writeAsString(jsonString, flush: true);

      if (context.mounted) {
        _snack(context, '✅ AsyncAPI exported to $savePath', success: true);
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, '❌ AsyncAPI export failed: $e', success: false);
      }
    }
  }

  // ── AsyncAPI 2.6 import (WebSocket endpoints) ────────────────────────────

  static Future<List<WsMockModel>?> importAsyncApi(
    BuildContext context,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import AsyncAPI spec',
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return null;

      final filePath = result.files.single.path;
      if (filePath == null) return null;

      final raw = _decodeInterp(await File(filePath).readAsString());
      final Map<String, dynamic> spec =
          jsonDecode(raw) as Map<String, dynamic>;

      final version = spec['asyncapi'] as String? ?? '';
      if (!version.startsWith('2.')) {
        if (context.mounted) {
          _snack(
            context,
            '❌ Only AsyncAPI 2.x files are supported.',
            success: false,
          );
        }
        return null;
      }

      final wsModels = <WsMockModel>[];
      final channels = spec['channels'] as Map<String, dynamic>? ?? {};

      for (final entry in channels.entries) {
        final path = entry.key;
        final channel = entry.value as Map<String, dynamic>? ?? {};

        final enable = channel['x-mockondo-enable'] as bool? ?? false;
        final onConnect = channel['x-mockondo-on-connect'] as String?;

        // Prefer x-mockondo-rules over reconstructing from message schema
        List<WsMockRule> rules = [];
        final rulesJson = channel['x-mockondo-rules'] as List<dynamic>?;
        if (rulesJson != null) {
          rules = rulesJson
              .whereType<Map<String, dynamic>>()
              .map(WsMockRule.fromJson)
              .toList();
        } else {
          // Reconstruct rules from subscribe.message
          final sub = channel['subscribe'] as Map<String, dynamic>?;
          final msg = sub?['message'] as Map<String, dynamic>?;
          if (msg != null) {
            final oneOf = msg['oneOf'] as List<dynamic>?;
            final messagesToParse =
                oneOf != null ? oneOf.cast<Map<String, dynamic>>() : [msg];
            for (final m in messagesToParse) {
              final pattern =
                  m['x-mockondo-pattern'] as String? ?? m['name'] as String? ?? '';
              final isRegex = m['x-mockondo-is-regex'] as bool? ?? false;
              final payload = m['payload'] as Map<String, dynamic>? ?? {};
              final response = payload['example']?.toString() ?? '';
              if (pattern.isNotEmpty) {
                rules.add(WsMockRule(
                  id: UuidV4().generate(),
                  pattern: pattern,
                  isRegex: isRegex,
                  response: response,
                ));
              }
            }
          }
        }

        List<WsScheduledMessage> scheduled = [];
        final schedJson =
            channel['x-mockondo-scheduled-messages'] as List<dynamic>?;
        if (schedJson != null) {
          scheduled = schedJson
              .whereType<Map<String, dynamic>>()
              .map(WsScheduledMessage.fromJson)
              .toList();
        }

        wsModels.add(WsMockModel(
          enable: enable,
          endpoint: path,
          onConnectMessage: onConnect,
          rules: rules,
          scheduledMessages: scheduled,
        ));
      }

      if (context.mounted) {
        _snack(
          context,
          '✅ Imported ${wsModels.length} WebSocket channel(s) from AsyncAPI spec',
          success: true,
        );
      }
      return wsModels;
    } catch (e) {
      if (context.mounted) {
        _snack(context, '❌ AsyncAPI import failed: $e', success: false);
      }
      return null;
    }
  }

  // ── Interpolation encoding helpers ───────────────────────────────────────

  /// Encodes Mockondo `${...}` placeholders to `{mockondo:...}` so they
  /// survive round-trips through OpenAPI / AsyncAPI tools.
  static String _encodeInterp(String s) =>
      s.replaceAllMapped(RegExp(r'\$\{(.*?)\}'), (m) => '{mockondo:${m[1]}}');

  /// Decodes `{mockondo:...}` back to `${...}` on import.
  static String _decodeInterp(String s) =>
      s.replaceAllMapped(RegExp(r'\{mockondo:(.*?)\}'), (m) => '\${${m[1]}}');

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _slug(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  static String _statusDescription(int code) {
    const m = {
      200: 'OK',
      201: 'Created',
      204: 'No Content',
      400: 'Bad Request',
      401: 'Unauthorized',
      403: 'Forbidden',
      404: 'Not Found',
      422: 'Unprocessable Entity',
      500: 'Internal Server Error',
    };
    return m[code] ?? 'Response';
  }

  static void _snack(
    BuildContext context,
    String message, {
    required bool success,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: success ? AppColors.greenD : AppColors.red,
            fontSize: AppTextSize.body,
          ),
        ),
        backgroundColor: AppColors.backgroundD,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
