import 'dart:convert';
import 'dart:math';

import 'package:mockondo/core/utils.dart';
import 'package:uuid/v4.dart';

import 'package:shelf/shelf.dart' as shelf;

enum InterpolationType { pagination }

class Interpolation {
  static String _randomInterpolations(
    List<String> keys,
    String data,
    Match match,
  ) {
    final method = keys.length > 2 ? '${keys[0]}.${keys[1]}' : keys.join('.');
    switch (method) {
      case 'random.index':
        return data;
      case 'random.integer':
        final max = keys.length > 2 ? int.tryParse(keys[2]) ?? 100 : 100;
        return Random().nextInt(max).toString();
      case 'random.double':
        final max = keys.length > 2 ? double.tryParse(keys[2]) ?? 100.0 : 1.0;
        return (Random().nextDouble() * max).toString();
      case 'random.string':
        final len = keys.length > 2 ? int.tryParse(keys[2]) ?? 20 : 20;
        return jsonEncode(Utils.randomString(len));
      case 'random.uuid':
        return jsonEncode(UuidV4().generate());

      /// random.image.400x400
      /// random.image.400x400.index
      /// random.image.400x400.gambar
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
  }

  static String _paginationInterpolations(
    List<String> keys,
    String data,
    Match match,
    shelf.Request? request,
  ) {
    final method = keys.length > 2 ? '${keys[0]}.${keys[1]}' : keys.join('.');
    switch (method) {
      case 'pagination.data':
        return data;
      case 'pagination.request':
        if (keys.length == 5 && keys[2] == 'url' && keys[3] == 'query') {
          return jsonEncode(request?.url.queryParameters[keys[4]] ?? '');
        }
        return data;
      default:
        return match.group(0)!;
    }
  }

  static _requestInterpolations(
    List<String> keys,
    String data,
    Match match,
    shelf.Request? request,
  ) {
    final method = keys.length > 2 ? '${keys[0]}.${keys[1]}' : keys.join('.');
    switch (method) {
      /// request.url.query.page
      case 'request.url':
        if (keys.length == 4 && keys[2] == 'query') {
          final param = request?.url.queryParameters[keys[3]] ?? '';

          final parsed = num.tryParse(param);
          if (parsed != null) {
            return parsed.toString();
          }

          return jsonEncode(param);
        }

        /// request.url.path.1
        /// for get data from path
        /// example : https://example.com/transaction/<transaction_id>
        if (keys.length == 4 && keys[2] == 'path') {
          final paths = request?.url.pathSegments[int.tryParse(keys[3]) ?? 0];

          return jsonEncode(paths);
        }

        return data;

      ///TODO: header
      ///TODO: body
      default:
        return match.group(0)!;
    }
  }

  String excute({
    required String before,
    required String data,
    shelf.Request? request,
  }) {
    final pattern = RegExp(r'\$\{(.*?)\}');
    return before.replaceAllMapped(pattern, (match) {
      final key = match.group(1)?.trim() ?? '';
      final keys = key.split('.');

      if (key.startsWith('random.')) {
        return _randomInterpolations(keys, data, match);
      }

      if (key.startsWith('request.')) {
        return _requestInterpolations(keys, data, match, request);
      }

      if (key.startsWith('pagination.')) {
        return _paginationInterpolations(keys, data, match, request);
      }

      return match.group(0)!;
    });
  }
}
