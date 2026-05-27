import 'dart:convert';
import 'dart:io';

import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';

abstract final class CoreLogFileSnapshot {
  static const int maxBytes = 64 * 1024;
  static const int defaultLineLimit = 80;

  static List<String> readTail(File file, {int lineLimit = defaultLineLimit}) {
    try {
      if (!file.existsSync()) return const ['core log file: missing'];
      final length = file.lengthSync();
      if (length <= 0) return const ['core log file: empty'];

      final start = length > maxBytes ? length - maxBytes : 0;
      final raf = file.openSync();
      try {
        raf.setPositionSync(start);
        final bytes = raf.readSync(length - start);
        final text = utf8.decode(bytes, allowMalformed: true);
        final lines = text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .map((line) => DiagnosticSanitizer.sanitize(line))
            .toList(growable: false);
        if (lines.isEmpty) return const ['core log file: empty'];
        final tail = lines.length > lineLimit ? lines.sublist(lines.length - lineLimit) : lines;
        return ['core log file: path=${DiagnosticSanitizer.sanitize(file.path)} size=$length', ...tail.reversed];
      } finally {
        raf.closeSync();
      }
    } catch (error) {
      return ['core log file: read failed ${DiagnosticSanitizer.sanitize(error.toString())}'];
    }
  }
}
