import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/auth/data/xboard_response_parser.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';

void main() {
  group('XBoardResponseParser', () {
    test('parses token from data.token', () {
      final token = XBoardResponseParser.parseToken({
        'data': {'token': 'abc123'},
      });

      expect(token, 'abc123');
    });

    test('parses token from data.auth_data and strips bearer prefix', () {
      final token = XBoardResponseParser.parseToken({
        'data': {'auth_data': 'Bearer xyz789'},
      });

      expect(token, 'xyz789');
    });

    test('throws readable failure when token missing', () {
      expect(() => XBoardResponseParser.parseToken({'data': {}}), throwsA(isA<AuthBadResponseFailure>()));
    });

    test('parses subscription url and traffic fields', () {
      final subscription = XBoardResponseParser.parseSubscription({
        'data': {
          'subscribe_url': 'https://example.com/api/v1/client/subscribe?token=sub-token',
          'expired_at': 1893456000,
          'u': 1024,
          'd': 2048,
          'transfer_enable': 4096,
        },
      });

      expect(subscription.subscribeUrl, 'https://example.com/api/v1/client/subscribe?token=sub-token');
      expect(subscription.upload, 1024);
      expect(subscription.download, 2048);
      expect(subscription.transferEnable, 4096);
      expect(subscription.remainingTraffic, 1024);
      expect(subscription.expiredAt, DateTime.fromMillisecondsSinceEpoch(1893456000 * 1000));
    });

    test('parses camelCase subscription response fields', () {
      final subscription = XBoardResponseParser.parseSubscription({
        'data': {
          'subscribeUrl': 'https://example.com/sub',
          'expiredAt': '2030-01-01T00:00:00Z',
          'upload': '10',
          'download': '15',
          'transferEnable': '100',
        },
      });

      expect(subscription.subscribeUrl, 'https://example.com/sub');
      expect(subscription.upload, 10);
      expect(subscription.download, 15);
      expect(subscription.transferEnable, 100);
      expect(subscription.remainingTraffic, 75);
      expect(subscription.expiredAt, DateTime.parse('2030-01-01T00:00:00Z'));
    });
  });
}
