import 'dart:convert';
import 'dart:io';

import 'package:mockondo/core/log.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
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

  /// Add a new router
  void addRouter(Router router) {
    _customRouters.add(router);
  }

  /// Remove all custom routers
  void clearRouters() {
    _customRouters.clear();
  }

  /// Combine all routers including main router and custom routers
  Handler _buildHandler() {
    Cascade cascade = Cascade().add(_mainRouter);

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

  /// Fallback handler: proxy request ke API eksternal
  Future<Response> _fallbackHandler(Request request) async {
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
    server = await serve(_buildHandler(), InternetAddress.anyIPv4, _port);
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
