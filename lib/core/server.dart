import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mockondo/core/log.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

class MainServer {
  LogService logService = LogService();

  HttpServer? server;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  Uri _host = Uri();

  set setHost(String value) {
    _host = Uri.parse(value);
  }

  Uri get host => _host;

  int _port = 8080;

  set setPort(int value) {
    _port = value;
  }

  int get port => _port;

  String _localIp = '';

  set setLocalIp(String value) {
    _localIp = value;
  }

  String get localIp => _localIp;

  final Router _mainRouter = Router();
  final List<Router> _customRouters = [];

  /// WebSocket handlers: each entry maps a path to its shelf handler.
  final List<({String path, Handler handler})> _wsHandlers = [];

  MainServer() {
    // Default routes
    _mainRouter.get('/', (Request request) => Response.ok('Hello, World!'));
    _mainRouter.get(
      '/hello/<name>',
      (Request request, String name) => Response.ok('Hello, $name!'),
    );
    _mainRouter.post('/echo', (Request request) async {
      final body = await request.readAsString();
      return Response.ok('You posted: $body');
    });
  }

  /// Add a new HTTP router.
  void addRouter(Router router) {
    _customRouters.add(router);
  }

  /// Remove all custom HTTP routers.
  void clearRouters() {
    _customRouters.clear();
  }

  /// Registers a WebSocket endpoint from a [WsMockModel].
  ///
  /// When a client connects to [model.endpoint], the server sends
  /// [WsMockModel.onConnectMessage] (if set) and then evaluates
  /// [WsMockModel.rules] against every incoming message.
  void addWsEndpoint(WsMockModel model) {
    final handler = webSocketHandler((WebSocketChannel channel, String? protocol) {
      // Send the on-connect message if one is configured.
      final connectMsg = model.onConnectMessage;
      if (connectMsg != null && connectMsg.isNotEmpty) {
        channel.sink.add(connectMsg);
      }

      logService.record(
        LogModel(status: Status.request, log: 'WS ${model.endpoint} ← connected'),
      );

      // Start scheduled messages for this client connection.
      final timers = <Timer>[];
      for (final sched in model.scheduledMessages) {
        if (!sched.enabled || sched.message.isEmpty) continue;
        final t = Timer(Duration(milliseconds: sched.delayMs), () {
          channel.sink.add(sched.message);
          logService.record(
            LogModel(
              status: Status.request,
              log: 'WS ${model.endpoint} → [scheduled] ${sched.message}',
            ),
          );
          if (sched.repeat && sched.intervalMs > 0) {
            timers.add(
              Timer.periodic(Duration(milliseconds: sched.intervalMs), (_) {
                channel.sink.add(sched.message);
                logService.record(
                  LogModel(
                    status: Status.request,
                    log: 'WS ${model.endpoint} → [scheduled] ${sched.message}',
                  ),
                );
              }),
            );
          }
        });
        timers.add(t);
      }

      channel.stream.listen(
        (message) {
          final msg = message.toString();
          logService.record(
            LogModel(status: Status.request, log: 'WS ${model.endpoint} ← $msg'),
          );

          // Evaluate rules in order; first match wins.
          for (final rule in model.rules) {
            if (rule.matches(msg)) {
              channel.sink.add(rule.response);
              logService.record(
                LogModel(
                  status: Status.request,
                  log: 'WS ${model.endpoint} → ${rule.response}',
                ),
              );
              return;
            }
          }
        },
        onDone: () {
          for (final t in timers) {
            t.cancel();
          }
          logService.record(
            LogModel(status: Status.request, log: 'WS ${model.endpoint} ← disconnected'),
          );
        },
      );
    });

    _wsHandlers.add((path: model.endpoint, handler: handler));
  }

  /// Remove all registered WebSocket endpoints.
  void clearWsEndpoints() => _wsHandlers.clear();

  /// Combine all routers including main router and custom routers
  Handler _buildHandler() {
    // WebSocket handlers are mounted first so upgrade requests are intercepted
    // before the HTTP cascade gets a chance to return 404.
    final wsRouter = Router();
    for (final ws in _wsHandlers) {
      wsRouter.get(ws.path, ws.handler);
    }

    Cascade cascade = Cascade().add(wsRouter.call);
    cascade = cascade.add(_mainRouter);

    for (final router in _customRouters) {
      cascade = cascade.add(router.call);
    }

    cascade = cascade.add(_fallbackHandler);

    return Pipeline()
        .addMiddleware(
          logRequests(
            logger: (message, isError) {
              logService.record(
                LogModel(
                  status: isError ? Status.error : Status.request,
                  log: message,
                ),
              );
            },
          ),
        )
        .addHandler(cascade.handler);
  }

  /// Fallback handler: proxy request ke API eksternal.
  /// Returns 404 immediately when no proxy host has been configured.
  Future<Response> _fallbackHandler(Request request) async {
    if (_host.host.isEmpty) {
      return Response.notFound('No mock endpoint matched: /${request.url}');
    }

    final uri = Uri(
      scheme: host.scheme,
      host: host.host,
      path: request.url.path,
      queryParameters: request.url.queryParameters,
    );

    final clientRequest = http.Request(request.method, uri);

    final excludedHeaders = {'host', 'content-length', 'transfer-encoding'};
    request.headers.forEach((key, value) {
      if (!excludedHeaders.contains(key.toLowerCase())) {
        clientRequest.headers[key] = value;
      }
    });

    if (request.method != 'GET' && request.method != 'HEAD') {
      clientRequest.body = await request.readAsString();
    }

    try {
      final streamedResponse = await clientRequest.send();

      final encoding =
          streamedResponse.headers['content-encoding']?.toLowerCase() ?? '';
      final isGzip = encoding.contains('gzip');

      final bytes = await streamedResponse.stream.toBytes();

      List<int> decompressedBytes;
      if (isGzip) {
        try {
          decompressedBytes = gzip.decode(bytes);
        } catch (e) {
          decompressedBytes = bytes;
        }
      } else {
        decompressedBytes = bytes;
      }

      final responseBody = utf8.decode(decompressedBytes);

      final responseHeaders = <String, String>{};
      streamedResponse.headers.forEach((key, value) {
        final lowerKey = key.toLowerCase();
        if (lowerKey != 'transfer-encoding' &&
            lowerKey != 'content-length' &&
            lowerKey != 'content-encoding') {
          responseHeaders[key] = value;
        }
      });

      responseHeaders['content-type'] = 'application/json; charset=utf-8';

      return Response(
        streamedResponse.statusCode,
        body: responseBody,
        headers: responseHeaders,
      );
    } catch (e) {
      return Response.internalServerError(body: 'Proxy request failed: $e');
    }
  }

  Future<void> run() async {
    server = await serve(
      _buildHandler(),
      InternetAddress.anyIPv4,
      _port,
      shared: true,
    );
    _isRunning = true;
    logService.record(
      LogModel(
        status: Status.request,
        log: '✅ Server running on http://$localIp:${server?.port}',
      ),
    );
    print('✅ Server running on http://$localIp:${server?.port}');
  }

  stop() {
    server?.close(force: true);
    logService.record(LogModel(status: Status.request, log: '❌ Stop server'));
    _isRunning = false;
  }
}
