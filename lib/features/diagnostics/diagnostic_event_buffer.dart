import 'dart:collection';

import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';

abstract final class DiagnosticEventBuffer {
  static final Queue<String> _events = Queue<String>();
  static const int _maxEvents = 100;

  static void add(String message) {
    final time = DateTime.now().toIso8601String().split('T').last.split('.').first;
    final sanitized = DiagnosticSanitizer.sanitize(message);
    _events.addFirst('$time $sanitized');
    while (_events.length > _maxEvents) {
      _events.removeLast();
    }
  }

  static List<String> recent({int limit = _maxEvents}) {
    return _events.take(limit).toList(growable: false);
  }
}
