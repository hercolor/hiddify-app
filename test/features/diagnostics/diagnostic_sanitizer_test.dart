import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/diagnostics/diagnostic_sanitizer.dart';

void main() {
  group('DiagnosticSanitizer', () {
    test('hides tokens, subscription links, node secrets, and full addresses', () {
      final sanitized = DiagnosticSanitizer.sanitize(
        'Authorization: Bearer abcdefghijklmnopqrstuvwxyz123456 '
        'url=https://api.example.com/api/v1/client/subscribe?token=secret '
        'server=node.example.com address=1.2.3.4 password=p@ssw0rd uuid=12345678901234567890123456789012 '
        'vless://very-secret@example.com:443',
      );

      expect(sanitized, isNot(contains('abcdefghijklmnopqrstuvwxyz123456')));
      expect(sanitized, isNot(contains('api.example.com')));
      expect(sanitized, isNot(contains('secret')));
      expect(sanitized, isNot(contains('node.example.com')));
      expect(sanitized, isNot(contains('1.2.3.4')));
      expect(sanitized, isNot(contains('p@ssw0rd')));
      expect(sanitized, isNot(contains('12345678901234567890123456789012')));
      expect(sanitized, contains('Authorization=***'));
      expect(sanitized, contains('https://***'));
      expect(sanitized, contains('vless://***'));
    });

    test('masks user id email', () {
      expect(DiagnosticSanitizer.maskIdentifier('user@example.com'), 'u***@***');
      expect(DiagnosticSanitizer.maskIdentifier('1234567890'), '1234***90');
    });

    test('keeps Go struct field names visible for import diagnostics', () {
      final sanitized = DiagnosticSanitizer.sanitize(
        'json: cannot unmarshal string into Go struct field Rule.DomainSuffixes of type []string',
      );

      expect(sanitized, contains('Go struct field Rule.DomainSuffixes'));
      expect(sanitized, contains('type []string'));
      expect(sanitized, isNot(contains('Rule.***')));
    });

    test('keeps Dart status labels visible while masking lowercase hosts', () {
      final sanitized = DiagnosticSanitizer.sanitize(
        'coreStatus=ConnectionStatus.connected() host=api.example.com status=CONNECTED',
      );

      expect(sanitized, contains('ConnectionStatus.connected()'));
      expect(sanitized, contains('status=CONNECTED'));
      expect(sanitized, isNot(contains('api.example.com')));
    });
  });
}
