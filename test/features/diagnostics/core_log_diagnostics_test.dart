import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/diagnostics/core_log_diagnostics.dart';

void main() {
  group('CoreLogDiagnostics', () {
    test('captures routing and DNS evidence lines', () {
      expect(CoreLogDiagnostics.shouldCapture('download rule-set geosite-cn', level: 'INFO'), isTrue);
      expect(
        CoreLogDiagnostics.shouldCapture('router: match rule_set geoip-cn outbound direct', level: 'DEBUG'),
        isTrue,
      );
      expect(CoreLogDiagnostics.shouldCapture('dns: exchanged ip.cn A record', level: 'DEBUG'), isTrue);
      expect(CoreLogDiagnostics.shouldCapture('background heartbeat tick', level: 'INFO'), isFalse);
    });

    test('captures warnings and errors even without keywords', () {
      expect(CoreLogDiagnostics.shouldCapture('unexpected service problem', level: 'WARNING'), isTrue);
      expect(CoreLogDiagnostics.shouldCapture('unexpected service problem', level: 'ERROR'), isTrue);
    });

    test('sanitizes and truncates summarized log lines', () {
      final summary = CoreLogDiagnostics.summarizeLine(
        'download rule-set from https://api.example.com/rules/sing-box/geoip-cn.srs server=1.2.3.4 token=secret ${List.filled(500, 'x').join()}',
        type: 'CORE',
        level: 'INFO',
      );

      expect(summary, startsWith('core runtime core/info:'));
      expect(summary, contains('https://***'));
      expect(summary, isNot(contains('api.example.com')));
      expect(summary, isNot(contains('1.2.3.4')));
      expect(summary.length, lessThanOrEqualTo(CoreLogDiagnostics.maxLineLength + 'core runtime core/info: '.length));
    });
  });
}
