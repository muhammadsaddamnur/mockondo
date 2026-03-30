import 'dart:convert';

import 'package:mockondo/features/http_client/data/models/http_client_model.dart';
import 'package:uuid/v4.dart';

class CurlUtils {
  /// Generate a cURL string from mock endpoint info.
  static String generate({
    required String method,
    required String url,
    Map<String, String> headers = const {},
    String? body,
  }) {
    final parts = <String>['curl -X $method'];

    for (final e in headers.entries) {
      parts.add("-H '${e.key}: ${e.value}'");
    }

    if (body != null && body.isNotEmpty) {
      final escaped = body.replaceAll("'", r"'\''");
      parts.add("--data-raw '$escaped'");
    }

    parts.add("'$url'");
    return parts.join(' \\\n  ');
  }

  /// Parse a cURL string into an [HttpRequestItem]. Returns null if invalid.
  static HttpRequestItem? parse(String curl) {
    try {
      final cleaned = curl
          .replaceAll('\\\r\n', ' ')
          .replaceAll('\\\n', ' ')
          .replaceAll('\r\n', ' ')
          .replaceAll('\n', ' ')
          // Handle case where TextField strips newlines, leaving bare backslashes
          .replaceAll(RegExp(r'\\\s+'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (!cleaned.toLowerCase().startsWith('curl')) return null;

      final tokens = _tokenize(cleaned.substring(4).trim());

      String? method;
      String? url;
      final headers = <KeyValuePair>[];
      var body = '';
      var bodyType = RequestBodyType.none;
      final formData = <KeyValuePair>[];

      int i = 0;
      while (i < tokens.length) {
        final t = tokens[i];

        if (t == '-X' || t == '--request') {
          i++;
          if (i < tokens.length) method = tokens[i].toUpperCase();
        } else if (t == '-H' || t == '--header') {
          i++;
          if (i < tokens.length) {
            final idx = tokens[i].indexOf(':');
            if (idx > 0) {
              headers.add(KeyValuePair(
                key: tokens[i].substring(0, idx).trim(),
                value: tokens[i].substring(idx + 1).trim(),
              ));
            }
          }
        } else if (t == '-d' ||
            t == '--data' ||
            t == '--data-raw' ||
            t == '--data-binary' ||
            t == '--data-ascii') {
          i++;
          if (i < tokens.length) {
            body = tokens[i];
            try {
              jsonDecode(body);
              bodyType = RequestBodyType.json;
            } catch (_) {
              bodyType = RequestBodyType.text;
            }
          }
        } else if (t == '-F' || t == '--form' || t == '--form-string') {
          i++;
          if (i < tokens.length) {
            final eqIdx = tokens[i].indexOf('=');
            formData.add(eqIdx > 0
                ? KeyValuePair(
                    key: tokens[i].substring(0, eqIdx),
                    value: tokens[i].substring(eqIdx + 1),
                  )
                : KeyValuePair(key: tokens[i]));
            bodyType = RequestBodyType.formData;
          }
        } else if (t.startsWith('--url=')) {
          url ??= t.substring(6);
        } else if (!t.startsWith('-')) {
          url ??= t;
        }

        i++;
      }

      method ??= (body.isNotEmpty || formData.isNotEmpty) ? 'POST' : 'GET';

      // Extract query params from URL into the params list
      final params = <KeyValuePair>[];
      String cleanUrl = url ?? '';
      final parsedUri = Uri.tryParse(cleanUrl);
      if (parsedUri != null && parsedUri.queryParameters.isNotEmpty) {
        for (final e in parsedUri.queryParameters.entries) {
          params.add(KeyValuePair(key: e.key, value: e.value));
        }
        cleanUrl = parsedUri.removeFragment().replace(queryParameters: {}).toString();
        // Remove trailing '?' if present
        if (cleanUrl.endsWith('?')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
      }

      return HttpRequestItem(
        id: UuidV4().generate(),
        name: _nameFromUrl(url ?? ''),
        method: method,
        url: cleanUrl,
        headers: headers,
        params: params,
        body: body,
        bodyType: bodyType,
        formData: formData,
      );
    } catch (_) {
      return null;
    }
  }

  static String _nameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments.where((s) => s.isNotEmpty).join(' / ');
      return path.isEmpty ? (uri.host.isEmpty ? 'Imported Request' : uri.host) : path;
    } catch (_) {
      return 'Imported Request';
    }
  }

  /// Tokenizes a cURL argument string, respecting single and double quotes.
  static List<String> _tokenize(String input) {
    final tokens = <String>[];
    final buf = StringBuffer();
    var inSingle = false;
    var inDouble = false;

    for (int i = 0; i < input.length; i++) {
      final c = input[i];
      if (c == "'" && !inDouble) {
        inSingle = !inSingle;
      } else if (c == '"' && !inSingle) {
        inDouble = !inDouble;
      } else if (c == ' ' && !inSingle && !inDouble) {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(c);
      }
    }
    if (buf.isNotEmpty) tokens.add(buf.toString());
    return tokens;
  }
}
