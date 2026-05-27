import 'dart:collection';

import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';

abstract final class DiagnosticEventBuffer {
  static final Queue<String> _events = Queue<String>();
  static const int _maxEvents = 180;

  static void add(String message) {
    _addSanitized(DiagnosticSanitizer.sanitize(message));
  }

  static void addSafe(String message) {
    _addSanitized(message);
  }

  static void _addSanitized(String message) {
    final time = DateTime.now().toIso8601String().split('T').last.split('.').first;
    _events.addFirst('$time $message');
    while (_events.length > _maxEvents) {
      _events.removeLast();
    }
  }

  static List<String> recent({int limit = _maxEvents}) {
    return _events.take(limit).toList(growable: false);
  }
}
