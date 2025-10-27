import 'dart:convert';
import 'dart:math';

class Utils {
  static Map<String, Object>? parseHeader(String jsonString) {
    if (jsonString.isEmpty) return null;
    final decoded = jsonDecode(jsonString);

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
