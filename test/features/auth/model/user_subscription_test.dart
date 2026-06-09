import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';

void main() {
  group('UserSubscription.canConnect', () {
    const activeSubscription = UserSubscription(
      subscribeUrl: 'https://example.com/sub',
      membershipStatus: 'month',
      planName: '月卡',
    );

    test('allows active paid membership', () {
      expect(activeSubscription.canConnect, isTrue);
    });

    test('blocks expired membership even when expiredAt is missing', () {
      const subscription = UserSubscription(
        subscribeUrl: 'https://example.com/sub',
        membershipStatus: 'expired',
        planName: '月卡',
      );

      expect(subscription.canConnect, isFalse);
    });

    test('normalizes membership and subscription statuses before access checks', () {
      final subscription = activeSubscription.copyWith(
        membershipStatus: ' Month ',
        subscriptionStatus: ' Traffic_Exhausted ',
      );

      expect(subscription.canConnect, isFalse);
      expect(subscription.isTrafficUnavailable, isTrue);
    });

    test('blocks unavailable subscription statuses', () {
      for (final status in const ['expired', 'traffic_exhausted', 'banned']) {
        final subscription = activeSubscription.copyWith(subscriptionStatus: status);

        expect(subscription.canConnect, isFalse, reason: status);
      }
    });

    test('server canConnect cannot override local expiry and traffic exhaustion', () {
      final expired = activeSubscription.copyWith(serverCanConnect: true, expiredAt: DateTime(2000));
      const trafficExhausted = UserSubscription(
        subscribeUrl: 'https://example.com/sub',
        membershipStatus: 'month',
        transferEnable: 100,
        upload: 100,
        serverCanConnect: true,
      );

      expect(expired.canConnect, isFalse);
      expect(trafficExhausted.canConnect, isFalse);
    });
  });
}
