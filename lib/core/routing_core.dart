import 'dart:convert';

import 'package:get/get.dart';
import 'package:mockondo/core/generate_core.dart';
import 'package:mockondo/core/interpolation.dart';
import 'package:mockondo/core/log.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:mockondo/core/utils.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart' as shelf_router;

/// Builds shelf [Router] instances from [MockModel] definitions.
///
/// Each [MockModel] produces one router entry for its configured HTTP method.
/// Requests are handled by [handleRequest] which:
///   1. Evaluates conditional response rules in order (first match wins).
///   2. Runs interpolation on headers and body.
///   3. Applies the optional artificial delay.
class RoutingCore {
  /// Returns a [shelf_router.Router] wired to the endpoint defined by
  /// [mockModel] using the given HTTP [method].
  shelf_router.Router getRouter(String method, MockModel mockModel) {
    // Resolve interpolation in the endpoint path at registration time so that
    // placeholders like ${customdata.cities.jakarta} become literal path segments.
    // Resolve interpolation in the path, then strip any JSON-encoded string
    // quotes (e.g. /"wkwk" → /wkwk) since URL paths never contain quotes.
    // ${:name} path parameter placeholders are converted to <name> for shelf_router.
    final endpoint = Interpolation()
        .excute(before: mockModel.endpoint, data: '')
        .replaceAll('"', '')
        .replaceAllMapped(RegExp(r'\$\{:(\w+)\}'), (m) => '<${m.group(1)}>');

    // Partition rules into pagination (at most one) and response overrides.
    final rules = mockModel.rules ?? [];

    final pagination = rules.firstWhereOrNull(
      (e) => e.type == RulesType.pagination,
    );
    final responseRules =
        rules.where((e) => e.type == RulesType.response).toList();

    /// Core handler shared by all HTTP methods.
    Future<shelf.Response> handleRequest(shelf.Request request) async {
      final sw = Stopwatch()..start();

      // Read the request body once so it can be used in rule evaluation and
      // body interpolation without consuming the stream twice.
      final requestBodyStr = await request.readAsString();

      // Start with the endpoint's default response values.
      String resolvedBody = mockModel.responseBody;
      int resolvedStatusCode = mockModel.statusCode;
      Map<String, Object>? resolvedHeader = mockModel.responseHeader;

      // Walk the response rules; the first matching rule overrides the defaults.
      for (final rule in responseRules) {
        if (_matchesResponseRule(rule, request, requestBodyStr)) {
          resolvedBody = rule.response;
          resolvedStatusCode = rule.ruleStatusCode;
          if (rule.responseHeader != null) {
            resolvedHeader = rule.responseHeader;
          }
          break; // First match wins — evaluation order.
        }
      }

      // Resolve interpolation placeholders in the response headers.
      // Use '{}' when resolvedHeader is null so Utils.parseHeader gets a
      // valid JSON object string instead of the literal "null".
      final headerJson =
          resolvedHeader != null ? jsonEncode(resolvedHeader) : '{}';
      final header = Interpolation().excute(
        request: request,
        before: headerJson,
        data: headerJson,
        requestBody: requestBodyStr,
      );

      // Generate the response body: pagination mode or plain interpolation.
      String body;
      try {
        body =
            pagination == null
                ? Interpolation().excute(
                  request: request,
                  before: resolvedBody,
                  data: resolvedBody,
                  requestBody: requestBodyStr,
                )
                : GenerateCore.pagination(
                  request: request,
                  responseBody: resolvedBody,
                  pagination: pagination,
                );
      } catch (e) {
        body = '{"error":"Response generation failed: $e"}';
        resolvedStatusCode = 500;
      }

      // Apply the optional artificial delay before sending the response.
      await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));

      sw.stop();

      final parsedResponseHeaders =
          Utils.parseHeader(header, interpolation: false);

      // Record structured log entry.
      LogService().record(LogModel(
        status: resolvedStatusCode >= 500 ? Status.error : Status.request,
        log: '${request.method} ${request.requestedUri.path} $resolvedStatusCode',
        method: request.method,
        path:
            request.requestedUri.path +
            (request.requestedUri.query.isNotEmpty
                ? '?${request.requestedUri.query}'
                : ''),
        requestHeaders: request.headers
            .map((k, v) => MapEntry(k, v)),
        requestBody: requestBodyStr.isEmpty ? null : requestBodyStr,
        statusCode: resolvedStatusCode,
        responseHeaders: parsedResponseHeaders
            ?.map((k, v) => MapEntry(k, v.toString())),
        responseBody: body.isEmpty ? null : body,
        durationMs: sw.elapsedMilliseconds,
      ));

      return shelf.Response(
        resolvedStatusCode,
        headers: parsedResponseHeaders,
        body: body,
      );
    }

    // Register the handler on the correct HTTP method.
    switch (method) {
      case 'GET':
        return shelf_router.Router()
          ..get(endpoint, (shelf.Request r) => handleRequest(r));
      case 'POST':
        return shelf_router.Router()
          ..post(endpoint, (shelf.Request r) => handleRequest(r));
      case 'PUT':
        return shelf_router.Router()
          ..put(endpoint, (shelf.Request r) => handleRequest(r));
      case 'PATCH':
        return shelf_router.Router()
          ..patch(endpoint, (shelf.Request r) => handleRequest(r));
      case 'DELETE':
        return shelf_router.Router()
          ..delete(endpoint, (shelf.Request r) => handleRequest(r));
      default:
        // Fallback: treat unknown methods as a plain GET that returns a static message.
        return shelf_router.Router()
          ..get(endpoint, (shelf.Request request) async {
            await Future.delayed(Duration(milliseconds: mockModel.delay ?? 0));
            return shelf.Response.ok('This is custom route');
          });
    }
  }

  // ── Rule evaluation ──────────────────────────────────────────────────────────

  /// Returns `true` if [rule]'s conditions are satisfied by [request].
  ///
  /// Uses AND logic by default; switches to OR when [Rules.logic] is
  /// [RulesLogic.or].
  bool _matchesResponseRule(
    Rules rule,
    shelf.Request request,
    String requestBodyStr,
  ) {
    final conditions = rule.conditions;
    if (conditions.isEmpty) return false;

    final results =
        conditions
            .map((c) => _evaluateCondition(c, request, requestBodyStr))
            .toList();

    return rule.logic == RulesLogic.or
        ? results.any((r) => r)
        : results.every((r) => r);
  }

  /// Extracts the actual value for [condition.target] from [request] and
  /// tests it against [condition.operator] and [condition.value].
  bool _evaluateCondition(
    ResponseCondition condition,
    shelf.Request request,
    String requestBodyStr,
  ) {
    String? actualValue;

    switch (condition.target) {
      case ResponseRuleTarget.queryParam:
        actualValue = request.url.queryParameters[condition.key];
        break;

      case ResponseRuleTarget.requestHeader:
        // Header lookup is case-insensitive; try lowercase first.
        actualValue =
            request.headers[condition.key.toLowerCase()] ??
            request.headers[condition.key];
        break;

      case ResponseRuleTarget.bodyField:
        try {
          final body = jsonDecode(requestBodyStr) as Map<String, dynamic>;
          // Supports dot-notation keys like "user.address.city".
          actualValue = _getNestedValue(body, condition.key)?.toString();
        } catch (_) {}
        break;

      case ResponseRuleTarget.routeParam:
        // condition.key holds the zero-based path segment index as a string.
        final segments = request.url.pathSegments;
        final index = int.tryParse(condition.key);
        if (index != null && index < segments.length) {
          actualValue = segments[index];
        }
        break;
    }

    return _applyOperator(actualValue, condition.operator, condition.value);
  }

  /// Traverses [obj] using dot-separated [key] (e.g. `"user.address.city"`)
  /// and returns the nested value, or `null` if any segment is missing.
  dynamic _getNestedValue(Map<String, dynamic> obj, String key) {
    final parts = key.split('.');
    dynamic current = obj;
    for (final part in parts) {
      if (current is Map<String, dynamic>) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Applies [operator] to compare [actualValue] against [expectedValue].
  bool _applyOperator(
    String? actualValue,
    ResponseRuleOperator operator,
    String expectedValue,
  ) {
    switch (operator) {
      case ResponseRuleOperator.equals:
        return actualValue == expectedValue;
      case ResponseRuleOperator.notEquals:
        return actualValue != expectedValue;
      case ResponseRuleOperator.contains:
        return actualValue?.contains(expectedValue) ?? false;
      case ResponseRuleOperator.notContains:
        return !(actualValue?.contains(expectedValue) ?? false);
      case ResponseRuleOperator.regexMatch:
        try {
          return RegExp(expectedValue).hasMatch(actualValue ?? '');
        } catch (_) {
          return false;
        }
      case ResponseRuleOperator.isEmpty:
        return actualValue == null || actualValue.isEmpty;
      case ResponseRuleOperator.isNotEmpty:
        return actualValue != null && actualValue.isNotEmpty;
    }
  }
}
