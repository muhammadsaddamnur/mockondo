import 'package:flutter/material.dart';

/// Singleton service that holds a reactive list of [LogModel] entries.
///
/// Widgets listen to [logs] via [ValueListenableBuilder] or [TerminalWidget].
/// The mock server appends entries through [record].
class LogService {
  LogService._internal();
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;

  /// Reactive log list. UI components listen to this notifier for live updates.
  final ValueNotifier<List<LogModel>> logs = ValueNotifier([]);

  /// Appends [log] to the end of the list and notifies listeners.
  void record(LogModel log) {
    logs.value = [...logs.value, log];
  }

  /// Clears all log entries and notifies listeners.
  void clear() {
    logs.value = [];
  }
}

/// A single immutable log entry produced by the mock server.
class LogModel {
  /// Severity level of this entry.
  final Status status;

  /// Raw log message (e.g. "GET /api/users 200 12ms" or a server event).
  final String log;

  /// When the entry was recorded. Defaults to [DateTime.now()].
  final DateTime timestamp;

  LogModel({required this.status, required this.log, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

/// Severity level of a log entry.
enum Status {
  /// A normal incoming HTTP request.
  request,

  /// A server error or misconfiguration.
  error,
}
