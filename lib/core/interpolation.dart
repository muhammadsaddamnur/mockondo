import 'dart:convert';
import 'dart:math';

import 'package:faker/faker.dart';
import 'package:get/get.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:mockondo/core/utils.dart';
import 'package:mockondo/features/home/presentation/controllers/home_controller.dart';
import 'package:uuid/v4.dart';

import 'package:shelf/shelf.dart' as shelf;

/// Marker enum used to tag special interpolation passes (e.g. pagination).
enum InterpolationType { pagination }

/// The core interpolation engine.
///
/// Call [excute] to resolve all `${...}` placeholders inside a string.
/// Supported namespaces:
///   - `random.*`     — random data (uuid, name, email, integer, etc.)
///   - `request.*`    — values extracted from the incoming HTTP request
///   - `customdata.*` — user-defined custom data lists
///   - `pagination.*` — pagination context values
///   - `math.*`       — arithmetic expressions
class Interpolation {
  // ── random.* ─────────────────────────────────────────────────────────────────

  /// Resolves all `random.*` placeholders.
  ///
  /// [keys]  — the placeholder split by `.` (e.g. `['random', 'integer', '100']`)
  /// [data]  — the current iteration value (used by `random.index`)
  /// [match] — the original regex match, returned unchanged on unknown keys
  String _randomInterpolations(List<String> keys, String data, Match match) {
    try {
      // Normalise to a two-segment method key, e.g. "random.integer"
      final method = keys.length > 2 ? '${keys[0]}.${keys[1]}' : keys.join('.');
      switch (method) {
        // Returns the current iteration index (set by the pagination engine).
        case 'random.index':
          return data;

        // ${random.integer.100} → random int in [0, 100)
        case 'random.integer':
          final max = keys.length > 2 ? int.tryParse(keys[2]) ?? 100 : 100;
          return Random().nextInt(max).toString();

        // ${random.double.10.5} → random double in [0.0, 10.5)
        case 'random.double':
          final max = keys.length > 2 ? double.tryParse(keys[2]) ?? 100.0 : 1.0;
          return (Random().nextDouble() * max).toString();

        // ${random.string.20} → 20-character alphanumeric string (JSON-encoded)
        case 'random.string':
          final len = keys.length > 2 ? int.tryParse(keys[2]) ?? 20 : 20;
          return jsonEncode(Utils.randomString(len));

        case 'random.uuid':
          return jsonEncode(UuidV4().generate());

        case 'random.name':
          return jsonEncode(Faker().person.name());

        case 'random.username':
          return jsonEncode(Faker().internet.userName());

        case 'random.email':
          return jsonEncode(Faker().internet.email());

        case 'random.url':
          return jsonEncode(Faker().internet.httpUrl());

        case 'random.phone':
          return jsonEncode(Faker().phoneNumber.ja());

        case 'random.lorem':
          return jsonEncode(Faker().lorem.sentence());

        case 'random.jwt':
          return jsonEncode(Faker().jwt.valid());

        // Returns the current UTC timestamp in ISO-8601 format.
        case 'random.date':
          return jsonEncode(DateTime.now().toUtc().toIso8601String());

        // ${random.image.400x400}           → "https://placehold.co/400x400"
        // ${random.image.400x400.index}     → image URL with the current index as text
        // ${random.image.400x400.sometext}  → image URL with custom text overlay
        case 'random.image':
          if (keys.length > 2) {
            var text = '';
            if (keys.length > 3 && keys[3] == 'index') {
              text = '?text=$data';
            }
            if (keys.length > 3 && keys[3] != 'index') {
              text = '?text=${keys[3]}';
            }
            return jsonEncode('https://placehold.co/${keys[2]}$text');
          }
          return jsonEncode('https://placehold.co/600x400');

        default:
          return match.group(0)!;
      }
    } catch (e) {
      return match.group(0)!;
    }
  }

  // ── customdata.* ─────────────────────────────────────────────────────────────

  /// Resolves `customdata.*` placeholders against the user-defined data store.
  ///
  /// Supported forms:
  ///   - `${customdata.jakarta}`        → first value of the "jakarta" list
  ///   - `${customdata.random.jakarta}` → random value from the "jakarta" list
  ///   - `${customdata.jakarta.john}`   → "john" if it exists in the list
  String _customDataInterpolations(
    List<String> keys,
    String data,
    Match match,
  ) {
    try {
      final homeController = Get.find<HomeController>();

      // Determine whether this is a 2-key or 3-key method
      String method = keys[0];
      if (keys.length == 3) {
        method = '${keys[0]}.${keys[1]}';
      }

      switch (method) {
        case 'customdata':
          return jsonEncode(
            homeController.customData[keys[1]]?.first ?? match.group(0)!,
          );

        case 'customdata.random':
          final random = Random();
          final length = homeController.customData[keys[2]]?.length ?? 0;
          final randomItem =
              homeController.customData[keys[2]]?[random.nextInt(length)];
          return jsonEncode(randomItem);

        default:
          // ${customdata.jakarta.john} — check membership in the list
          if (keys.length == 3 && keys[0] == 'customdata') {
            final list = homeController.customData[keys[1]];
            if (list != null && list.contains(keys[2])) {
              return jsonEncode(keys[2]);
            }
          }
          return match.group(0)!;
      }
    } catch (e) {
      return match.group(0)!;
    }
  }

  // ── pagination.* ─────────────────────────────────────────────────────────────

  /// Resolves `pagination.*` placeholders.
  ///
  /// - `${pagination.data}`                        → the pre-generated page data
  /// - `${pagination.request.url.query.<param>}`   → a query param from the request
  String _paginationInterpolations(
    List<String> keys,
    String data,
    Match match,
    shelf.Request? request,
  ) {
    try {
      final method = keys.length > 2 ? '${keys[0]}.${keys[1]}' : keys.join('.');
      switch (method) {
        case 'pagination.data':
          return data;

        case 'pagination.request':
          // Format: pagination.request.url.query.<paramName>
          if (keys.length == 5 && keys[2] == 'url' && keys[3] == 'query') {
            return jsonEncode(request?.url.queryParameters[keys[4]] ?? '');
          }
          return data;

        default:
          return match.group(0)!;
      }
    } catch (e) {
      return match.group(0)!;
    }
  }

  // ── request.* ────────────────────────────────────────────────────────────────

  /// Resolves `request.*` placeholders against the live incoming [request].
  ///
  /// Supported forms:
  ///   - `${request.url.query.<param>}`      → URL query parameter value
  ///   - `${request.url.path.<index>}`       → URL path segment by zero-based index
  ///   - `${request.header.<headerName>}`    → request header value (case-insensitive)
  ///   - `${request.body.<field>}`           → JSON body field (supports dot notation)
  _requestInterpolations(
    List<String> keys,
    String data,
    Match match,
    shelf.Request? request,
    String? requestBody,
  ) {
    try {
      final method = keys.length > 2 ? '${keys[0]}.${keys[1]}' : keys.join('.');
      switch (method) {
        case 'request.url':
          if (keys.length == 4 && keys[2] == 'query') {
            final param = request?.url.queryParameters[keys[3]] ?? '';
            // Return numbers without quotes so they remain numeric in JSON
            final parsed = num.tryParse(param);
            if (parsed != null) return parsed.toString();
            return jsonEncode(param);
          }

          if (keys.length == 4 && keys[2] == 'path') {
            final paths = request?.url.pathSegments[int.tryParse(keys[3]) ?? 0];
            return jsonEncode(paths);
          }
          return data;

        case 'request.header':
          if (keys.length == 3) {
            // Header lookup is case-insensitive; fall back to original casing.
            final headerVal =
                request?.headers[keys[2].toLowerCase()] ??
                request?.headers[keys[2]] ??
                '';
            return jsonEncode(headerVal);
          }
          return data;

        case 'request.body':
          if (keys.length >= 3 && requestBody != null) {
            try {
              final bodyMap = jsonDecode(requestBody) as Map<String, dynamic>;
              // Support nested keys via dot notation, e.g. request.body.user.name
              final fieldKey = keys.sublist(2).join('.');
              dynamic current = bodyMap;
              for (final part in fieldKey.split('.')) {
                if (current is Map<String, dynamic>) {
                  current = current[part];
                } else {
                  return match.group(0)!;
                }
              }
              return jsonEncode(current);
            } catch (_) {
              return match.group(0)!;
            }
          }
          return data;

        default:
          return match.group(0)!;
      }
    } catch (e) {
      return match.group(0)!;
    }
  }

  // ── math.* ───────────────────────────────────────────────────────────────────

  /// Resolves `math.*` placeholders by evaluating the expression that follows.
  ///
  /// The expression is first run through [excute] so that nested interpolations
  /// (e.g. `${request.url.query.page}`) are resolved before evaluation.
  _mathInterpolations(
    List<String> keys,
    String data,
    Match match,
    shelf.Request? request,
  ) {
    try {
      final matchx = match.group(1)!;
      var expr = excute(before: matchx, data: data);

      // Strip the "math." prefix and clean up the remaining expression
      var s = expr.split('.');
      s.removeAt(0);
      var res = '';
      for (var x in s) {
        res += x.replaceAllMapped(RegExp(r'\.(\*|\+|\-|\/)\.'), (m) => m[1]!);
      }

      return evaluateMathExpression(res).toString();
    } catch (e) {
      return match.group(0)!;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────────

  /// Resolves all `${...}` placeholders in [before] and returns the result.
  ///
  /// - [data]        — current iteration value passed to `random.index` and
  ///                   `pagination.data` placeholders.
  /// - [request]     — the live shelf request; required for `request.*` and
  ///                   `pagination.request.*` placeholders.
  /// - [requestBody] — the already-read request body string; required for
  ///                   `request.body.*` placeholders.
  ///
  /// Unknown placeholders are left as-is.
  String excute({
    required String before,
    required String data,
    shelf.Request? request,
    String? requestBody,
  }) {
    final pattern = RegExp(r'\$\{(.*?)\}');
    return before.replaceAllMapped(pattern, (match) {
      final key = match.group(1)?.trim() ?? '';
      final keys = key.split('.');

      if (key.startsWith('random.')) {
        return _randomInterpolations(keys, data, match);
      }

      if (key.startsWith('customdata.')) {
        return _customDataInterpolations(keys, data, match);
      }

      if (key.startsWith('request.')) {
        return _requestInterpolations(keys, data, match, request, requestBody);
      }

      if (key.startsWith('pagination.')) {
        return _paginationInterpolations(keys, data, match, request);
      }

      if (key.startsWith('math.')) {
        return _mathInterpolations(keys, data, match, request);
      }

      // ${:paramName} — path parameter captured from the URL pattern (e.g. a/${:id}/detail)
      if (key.startsWith(':') && request != null) {
        final paramName = key.substring(1);
        final params = request.context['shelf_router/params'] as Map<String, String>?;
        final paramValue = params?[paramName] ?? '';
        final parsed = num.tryParse(paramValue);
        if (parsed != null) return parsed.toString();
        return jsonEncode(paramValue);
      }

      // Leave unrecognised placeholders unchanged.
      return match.group(0)!;
    });
  }

  /// Wraps (or unwraps) `${...}` placeholders inside a header JSON string so
  /// they survive `jsonEncode`/`jsonDecode` round-trips without being escaped.
  ///
  /// When [reverse] is `true`, converts the stored escaped form back to the
  /// raw `${...}` syntax (used when loading saved header data for display).
  String header({required String header, bool reverse = false}) {
    final pattern = RegExp(r'\$\{(.*?)\}');

    if (reverse) {
      return header.replaceAllMapped(
        RegExp(r'"\\?\$\{(.*?)\}"'),
        (match) => '\${${match.group(1)}}',
      );
    }

    final res = header.replaceAllMapped(pattern, (match) {
      return jsonEncode(match.group(0)!);
    });

    return res.replaceAll('""', '"');
  }

  /// Evaluates an arithmetic [expression] string (e.g. `"2+3*4"`) and returns
  /// the numeric result using the `math_expressions` package.
  num evaluateMathExpression(String expression) {
    final parser = GrammarParser();
    final parsed = parser.parse(expression);
    final evaluator = RealEvaluator();
    return evaluator.evaluate(parsed);
  }
}
