import 'dart:convert';
import 'dart:math';

import 'package:mockondo/core/utils.dart';

enum InterpolationType { pagination }

class Interpolation {
  String excute({
    required String before,
    required String data,
    required InterpolationType type,
  }) {
    final pattern = RegExp(r'\$\{(.*?)\}');
    return before.replaceAllMapped(pattern, (match) {
      final key = match.group(1)?.trim() ?? '';

      if (type == InterpolationType.pagination) {
        return _paginationInterpolation(
          before: before,
          data: data,
          key: key,
          match: match,
        );
      }

      switch (key) {
        default:
          return match.group(0)!;
      }
    });
  }

  String _paginationInterpolation({
    required String before,
    required String data,
    required Match match,
    required String key,
  }) {
    final keys = key.split('.');

    final method = keys.length > 2 ? '${keys[0]}.${keys[1]}' : key;

    switch (method) {
      case 'pagination.data':
        return data;
      case 'random.index':
        return data;
      case 'random.integer':
        if (keys.length > 2) {
          return Random().nextInt(int.tryParse(keys[2]) ?? 100).toString();
        }
        return Random().nextInt(100).toString();
      case 'random.double':
        if (keys.length > 2) {
          return (Random().nextDouble() * (double.tryParse(keys[2]) ?? 100.0))
              .toString();
        }
        return Random().nextDouble().toString();
      case 'random.string':
        if (keys.length > 2) {
          return jsonEncode(
            Utils.randomString(int.tryParse(keys[2]) ?? 20).toString(),
          );
        }
        return jsonEncode(Utils.randomString(20));

      /// random.image.400x400
      /// random.image.400x400.index
      case 'random.image':
        if (keys.length > 2) {
          var randomIndex = '';
          if (keys.length > 3 && keys[3] == 'index') {
            randomIndex = '?text=$data';
          }
          return jsonEncode('https://placehold.co/${keys[2]}$randomIndex');
        }
        return jsonEncode('https://placehold.co/600x400');
      default:
        return match.group(0)!;
    }
  }
}
