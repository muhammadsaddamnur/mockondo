import 'package:flutter/material.dart';

class LogService {
  // Private constructor
  LogService._internal();

  // Singleton instance
  static final LogService _instance = LogService._internal();

  // Factory constructor
  factory LogService() {
    return _instance;
  }

  // Log list
  final ValueNotifier<List<LogModel>> logs = ValueNotifier([]);

  // Method to add log
  void record(LogModel log) {
    logs.value = [...logs.value, log];
  }
}

class LogModel {
  final Status status;
  final String log;

  LogModel({required this.status, required this.log});
}

enum Status { request, error }
