import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/auth/widget/customer_service_uri.dart';

void main() {
  group('customerServiceUri', () {
    test('returns null for blank or unsupported values', () {
      expect(customerServiceUri(null), isNull);
      expect(customerServiceUri(''), isNull);
      expect(customerServiceUri('   '), isNull);
      expect(customerServiceUri('javascript:alert(1)'), isNull);
      expect(customerServiceUri('file:///tmp/support'), isNull);
      expect(customerServiceUri('BflyVPN support'), isNull);
      expect(customerServiceUri('https://'), isNull);
    });

    test('accepts configured web and Telegram links', () {
      expect(customerServiceUri('https://support.example.com')?.toString(), 'https://support.example.com');
      expect(customerServiceUri('http://support.example.com')?.toString(), 'http://support.example.com');
      expect(customerServiceUri('tg://resolve?domain=support')?.scheme, 'tg');
      expect(customerServiceUri('https://t.me/support')?.host, 't.me');
    });

    test('normalizes plain email to mailto', () {
      expect(customerServiceUri('support@example.com')?.toString(), 'mailto:support@example.com');
      expect(customerServiceUri('mailto:support@example.com')?.toString(), 'mailto:support@example.com');
    });
  });
}
