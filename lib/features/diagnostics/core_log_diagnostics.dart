import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart' as pb;

abstract final class CoreLogDiagnostics {
  static const int maxLineLength = 360;

  static final RegExp _interestingLinePattern = RegExp(
    r'\b(rule[-_ ]?set|geosite|geoip|dns|download|route|router|match|sniff|tun|inbound|resolve|resolver|error|warn|fail(?:ed|ure)?|ip138|ip\.cn|ipinfo)\b',
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

  static void addLogMessage(pb.LogMessage message) {
    final level = message.level.name;
    final type = message.type.name;
    for (final rawLine in message.message.split('\n')) {
      final line = rawLine.trim();
      if (!shouldCapture(line, level: level)) continue;
      DiagnosticEventBuffer.addSafe(summarizeLine(line, type: type, level: level));
    }
  }

  static String _truncate(String value) {
    if (value.length <= maxLineLength) return value;
    return '${value.substring(0, maxLineLength - 1)}…';
  }
}
