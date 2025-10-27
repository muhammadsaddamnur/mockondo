import 'dart:convert';

import 'package:mockondo/core/interpolation.dart';
import 'package:mockondo/core/mock_model.dart';
import 'package:shelf/shelf.dart' as shelf;

class GenerateCore {
  static String pagination({
    required shelf.Request request,
    required String responseBody,
    Rules? pagination,
  }) {
    final generatePagination = <String>[];

    final max = int.parse((pagination?.rules['max'] ?? '0').toString());
    final limit = int.parse(
      request.url.queryParameters[pagination?.rules['limit_param']] ?? '0',
    );

    /// for now we only support page
    final offset = int.parse(
      request.url.queryParameters[pagination?.rules['offset_param']] ?? '0',
    );

    if (pagination != null) {
      final maxLoop = limit * offset;

      if (maxLoop > max) {
        final encoded = jsonEncode(generatePagination);
        return Interpolation().excute(
          before: responseBody,
          data: encoded,
          type: InterpolationType.pagination,
        );
      }

      for (var i = 0; i < limit; i++) {
        var decode = jsonDecode(
          Interpolation().excute(
            before: pagination.response,
            data: '${(limit * offset) + i}',
            type: InterpolationType.pagination,
          ),
        );
        generatePagination.add(jsonEncode(decode));
      }
    }

    final parsed = generatePagination.map((e) => jsonDecode(e)).toList();
    final encoded = jsonEncode(parsed);

    // return encoded;
    return Interpolation().excute(
      before: responseBody,
      data: encoded,
      type: InterpolationType.pagination,
    );
  }
}
