import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart' as pb;

abstract final class CoreLogDiagnostics {
  static const int maxLineLength = 360;

  static final Map<String, int> _eventCounts = <String, int>{};
  static final Map<String, String> _listenerLevels = <String, String>{};
  static final Map<String, String> _streamStates = <String, String>{};
  static int _capturedLineCount = 0;

  static final RegExp _interestingLinePattern = RegExp(
    r'\b(rule[-_ ]?set|geosite|geoip|dns|download|route|router|match|sniff|tun|inbound|outbound|selector|direct|proxy|connect|connection|tcp|udp|tls|http|https|resolve|resolver|error|warn|fail(?:ed|ure)?|ip138|ip\.cn|ipinfo|skk|cf[-_ ]?geoip)\b',
    caseSensitive: false,
  );

  static bool shouldCapture(String line, {required String level}) {
    final text = line.trim();
    if (text.isEmpty) return false;

    final normalizedLevel = level.toLowerCase();
    if (normalizedLevel == 'warning' || normalizedLevel == 'error' || normalizedLevel == 'fatal') {
      return true;
    }

    return _interestingLinePattern.hasMatch(text);
  }

  static String summarizeLine(String line, {required String type, required String level}) {
    final sanitized = DiagnosticSanitizer.sanitize(line.trim()).replaceAll(RegExp(r'\s+'), ' ');
    return 'core runtime ${type.toLowerCase()}/${level.toLowerCase()}: ${_truncate(sanitized)}';
  }

  static void recordAttach({required String key, required String level}) {
    _listenerLevels[key] = level;
    _eventCounts.putIfAbsent(key, () => 0);
    _streamStates[key] = 'attached';
    DiagnosticEventBuffer.addSafe('core log listener attach key=$key level=$level');
  }

  static void recordStreamDone(String key) {
    _streamStates[key] = 'done';
    DiagnosticEventBuffer.addSafe('core log listener done key=$key events=${_eventCounts[key] ?? 0}');
  }

  static void recordStreamError(String key, Object error) {
    _streamStates[key] = 'error';
    DiagnosticEventBuffer.add('core log listener error key=$key events=${_eventCounts[key] ?? 0} error=$error');
  }

  static void recordEvent(String key, pb.LogMessage message) {
    final count = (_eventCounts[key] ?? 0) + 1;
    _eventCounts[key] = count;
    _streamStates[key] = 'receiving';
    if (count <= 5 || count % 25 == 0) {
      DiagnosticEventBuffer.addSafe(
        'core log listener event key=$key count=$count type=${message.type.name} level=${message.level.name} bytes=${message.message.length}',
      );
    }
  }

  static List<String> statusLines() {
    if (_listenerLevels.isEmpty) return const ['core log grpc: no listener attached'];
    final lines = <String>[
      'core log grpc: listeners=${_listenerLevels.entries.map((entry) => '${entry.key}:${entry.value}/${_streamStates[entry.key] ?? 'unknown'}/events=${_eventCounts[entry.key] ?? 0}').join(', ')} capturedLines=$_capturedLineCount',
    ];
    if (_eventCounts.values.every((count) => count == 0)) {
      lines.add('core log grpc: no events received; route decision trace unavailable from grpc listener');
    }
    return lines;
  }

  static void addLogMessage(pb.LogMessage message) {
    final level = message.level.name;
    final type = message.type.name;
    for (final rawLine in message.message.split('\n')) {
      final line = rawLine.trim();
      if (!shouldCapture(line, level: level)) continue;
      _capturedLineCount += 1;
      DiagnosticEventBuffer.addSafe(summarizeLine(line, type: type, level: level));
    }
  }

  static String _truncate(String value) {
    if (value.length <= maxLineLength) return value;
    return '${value.substring(0, maxLineLength - 1)}…';
  }
}
