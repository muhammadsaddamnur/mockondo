import 'dart:convert';
import 'dart:math';

import 'package:mockondo/core/interpolation.dart';

/// General-purpose utility functions used across the app.
class Utils {
  /// Parses a JSON string into a `Map<String, Object>` suitable for use as
  /// HTTP response headers.
  ///
  /// When [interpolation] is `true` (the default), any `${...}` placeholders
  /// inside header values are first resolved by [Interpolation.header] before
  /// JSON decoding. Pass `interpolation: false` when the string has already
  /// been processed or when called from within the interpolation pipeline
  /// (to avoid infinite recursion).
  ///
  /// Returns `null` for an empty [jsonString].
  /// Throws [FormatException] for non-object JSON or invalid value types.
  static Map<String, Object>? parseHeader(
    String jsonString, {
    bool interpolation = true,
  }) {
    if (jsonString.isEmpty) return null;
    final decoded =
        interpolation
            ? jsonDecode(
              Interpolation().header(header: jsonString.replaceAll('""', '"')),
            )
            : jsonDecode(jsonString.replaceAll('""', '"'));

    if (decoded is Map<String, dynamic>) {
      return decoded.map((key, value) {
        if (value is Object) {
          return MapEntry(key, value);
        } else {
          throw FormatException('Value for key "$key" is not an Object.');
        }
      });
    } else {
      throw FormatException('Invalid JSON format. Expected a JSON object.');
    }
  }

  /// Generates a random alphanumeric string of the given [length].
  ///
  /// Uses upper/lowercase letters and digits (62 possible characters).
  static String randomString(int length) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(
      length,
      (index) => chars[rand.nextInt(chars.length)],
    ).join();
  }
}
