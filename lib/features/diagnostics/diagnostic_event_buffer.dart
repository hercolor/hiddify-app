import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';

abstract final class DiagnosticEventBuffer {
  static const diagnosticVersion = '20260604-004-start-config-content';
  static final Queue<String> _events = Queue<String>();
  static const int _maxEvents = 180;

  static void add(String message) {
    _addSanitized(DiagnosticSanitizer.sanitize(message));
  }

  static void addSafe(String message) {
    _addSanitized(DiagnosticSanitizer.sanitize(message));
  }

  static void _addSanitized(String message) {
    final time = DateTime.now().toIso8601String().split('T').last.split('.').first;
    final event = '$time diagVersion=$diagnosticVersion $message';
    _events.addFirst(event);
    debugPrint('4376diag $event');
    while (_events.length > _maxEvents) {
      _events.removeLast();
    }
  }

  static List<String> recent({int limit = _maxEvents}) {
    return _events.take(limit).toList(growable: false);
  }
}
