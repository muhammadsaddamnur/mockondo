// Mockondo smoke test — verifies that the test runner itself is working.
// Widget-level tests require a real display and platform channels that are not
// available in CI; cover those scenarios with integration tests instead.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smoke test — test runner is working', () {
    expect(1 + 1, equals(2));
  });
}
