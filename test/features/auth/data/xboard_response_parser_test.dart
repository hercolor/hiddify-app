import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/auth/data/xboard_response_parser.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';

void main() {
  group('XBoardResponseParser', () {
    test('parses authData from data.auth_data and keeps bearer prefix', () {
      final authData = XBoardResponseParser.parseAuthData({
        'data': {'auth_data': 'Bearer xyz789'},
      });

      expect(authData, 'Bearer xyz789');
    });

    test('normalizes authData when bearer prefix is missing', () {
      final authData = XBoardResponseParser.parseAuthData({
        'data': {'auth_data': 'xyz789'},
      });

      expect(authData, 'Bearer xyz789');
    });

    test('deduplicates repeated bearer prefix in authData', () {
      final authData = XBoardResponseParser.parseAuthData({
        'data': {'auth_data': 'Bearer Bearer xyz789'},
      });

      expect(authData, 'Bearer xyz789');
    });

    test('parses subscribeToken from data.token separately', () {
      final subscribeToken = XBoardResponseParser.parseSubscribeToken({
        'data': {'token': 'abc123'},
      });

      expect(subscribeToken, 'abc123');
    });

    test('strips bearer prefix from subscribeToken only', () {
      final subscribeToken = XBoardResponseParser.parseSubscribeToken({
        'data': {'token': 'Bearer sub-token'},
      });

      expect(subscribeToken, 'sub-token');
    });

    test('throws readable failure when authData missing', () {
      expect(() => XBoardResponseParser.parseAuthData({'data': {}}), throwsA(isA<AuthBadResponseFailure>()));
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

    test('resolves relative XBoard subscribe_url against configured api base url', () {
      final subscription = XBoardResponseParser.parseSubscription({
        'data': {'subscribe_url': '/api/v1/client/subscribe?token=sub-token', 'expired_at': 1893456000},
      }, baseUrl: 'https://api.example.com');

      expect(subscription.subscribeUrl, 'https://api.example.com/api/v1/client/subscribe?token=sub-token');
    });

    test('uses fallback subscription url from login subscribe token while preserving user fields', () {
      final subscription = XBoardResponseParser.parseSubscription({
        'data': {
          'expired_at': 1893456000,
          'u': 1024,
          'd': 2048,
          'transfer_enable': 4096,
          'plan': {'name': '商业套餐'},
        },
      }, fallbackSubscribeUrl: 'https://example.com/api/v1/client/subscribe?token=sub-token');

      expect(subscription.subscribeUrl, 'https://example.com/api/v1/client/subscribe?token=sub-token');
      expect(subscription.planName, '商业套餐');
      expect(subscription.usedTraffic, 3072);
      expect(subscription.remainingTraffic, 1024);
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

    test('parses nested XBoard plan and device fields without exposing map text', () {
      final subscription = XBoardResponseParser.parseSubscription({
        'data': {
          'subscribe_url': 'https://example.com/sub',
          'u': 10,
          'd': 20,
          'transfer_enable': 100,
          'plan': {'name': '标准会员'},
          'online_devices': 1,
          'device_limit': 3,
        },
      });

      expect(subscription.planName, '标准会员');
      expect(subscription.onlineDevices, 1);
      expect(subscription.maxDevices, 3);
      expect(subscription.usedTraffic, 30);
      expect(subscription.remainingTraffic, 70);
    });

    test('parses customer service without using subscription url as fallback', () {
      final subscription = XBoardResponseParser.parseSubscription({
        'data': {'subscribe_url': 'https://example.com/sub?token=secret', 'customer_service': 'https://t.me/support'},
      });

      expect(subscription.customerService, 'https://t.me/support');
      expect(XBoardResponseParser.parseCustomerService({'data': {}}), isNull);
    });

    test('parses millisecond expire timestamp without multiplying twice', () {
      final subscription = XBoardResponseParser.parseSubscription({
        'data': {'subscribe_url': 'https://example.com/sub', 'expired_at': 1893456000000},
      });

      expect(subscription.expiredAt, DateTime.fromMillisecondsSinceEpoch(1893456000000));
    });

    test('clamps negative remaining traffic to zero', () {
      final subscription = XBoardResponseParser.parseSubscription({
        'data': {'subscribe_url': 'https://example.com/sub', 'u': 70, 'd': 50, 'transfer_enable': 100},
      });

      expect(subscription.usedTraffic, 120);
      expect(subscription.remainingTraffic, 0);
    });
  });
}
