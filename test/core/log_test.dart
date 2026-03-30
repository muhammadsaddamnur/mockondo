import 'package:flutter_test/flutter_test.dart';
import 'package:mockondo/core/log.dart';

void main() {
  // Reset singleton state between tests.
  setUp(() => LogService().clear());

  group('LogModel', () {
    test('sets timestamp to now when not supplied', () {
      final before = DateTime.now();
      final model = LogModel(status: Status.request, log: 'GET /api 200 5ms');
      final after = DateTime.now();

      expect(model.timestamp.isAfter(before) || model.timestamp == before, isTrue);
      expect(model.timestamp.isBefore(after) || model.timestamp == after, isTrue);
    });

    test('uses the provided timestamp when supplied', () {
      final ts = DateTime(2024, 6, 15, 12, 0, 0);
      final model = LogModel(status: Status.error, log: 'err', timestamp: ts);
      expect(model.timestamp, equals(ts));
    });

    test('stores status and log correctly', () {
      final model = LogModel(status: Status.error, log: 'Server error');
      expect(model.status, equals(Status.error));
      expect(model.log, equals('Server error'));
    });
  });

  group('LogService', () {
    test('is a singleton — same instance returned every time', () {
      expect(identical(LogService(), LogService()), isTrue);
    });

    test('starts with an empty log list', () {
      expect(LogService().logs.value, isEmpty);
    });

    test('record() appends entries in order', () {
      final svc = LogService();
      svc.record(LogModel(status: Status.request, log: 'first'));
      svc.record(LogModel(status: Status.request, log: 'second'));
      svc.record(LogModel(status: Status.error, log: 'third'));

      expect(svc.logs.value.length, equals(3));
      expect(svc.logs.value[0].log, equals('first'));
      expect(svc.logs.value[1].log, equals('second'));
      expect(svc.logs.value[2].log, equals('third'));
    });

    test('clear() empties the log list', () {
      final svc = LogService();
      svc.record(LogModel(status: Status.request, log: 'hello'));
      svc.clear();
      expect(svc.logs.value, isEmpty);
    });

    test('notifies listeners when record() is called', () {
      final svc = LogService();
      var notified = false;
      svc.logs.addListener(() => notified = true);
      svc.record(LogModel(status: Status.request, log: 'ping'));
      expect(notified, isTrue);
    });

    test('notifies listeners when clear() is called', () {
      final svc = LogService();
      svc.record(LogModel(status: Status.request, log: 'x'));
      var notified = false;
      svc.logs.addListener(() => notified = true);
      svc.clear();
      expect(notified, isTrue);
    });
  });
}
