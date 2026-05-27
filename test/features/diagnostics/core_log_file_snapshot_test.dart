import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/diagnostics/core_log_file_snapshot.dart';

void main() {
  group('CoreLogFileSnapshot', () {
    test('reports missing file', () {
      final dir = Directory.systemTemp.createTempSync('core-log-snapshot-missing-');
      try {
        final lines = CoreLogFileSnapshot.readTail(File('${dir.path}/missing.log'));
        expect(lines.single, 'core log file: missing');
      } finally {
        dir.deleteSync(recursive: true);
      }
    });

    test('reads sanitized tail lines newest first', () {
      final dir = Directory.systemTemp.createTempSync('core-log-snapshot-');
      try {
        final file = File('${dir.path}/box.log')
          ..writeAsStringSync(
            'old\n'
            'download rule-set https://api.example.com/rules/sing-box/geosite-cn.srs\n'
            'server=1.2.3.4 token=secret\n',
          );

        final lines = CoreLogFileSnapshot.readTail(file, lineLimit: 2);

        expect(lines.first, startsWith('core log file: path='));
        expect(lines, hasLength(3));
        expect(lines[1], isNot(contains('1.2.3.4')));
        expect(lines[1], contains('token=***'));
        expect(lines[2], contains('https://***'));
        expect(lines[2], isNot(contains('api.example.com')));
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  });
}
