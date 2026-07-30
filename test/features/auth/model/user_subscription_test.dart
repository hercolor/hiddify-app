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
        subscriptionStatus: ' Banned ',
      );

      expect(subscription.canConnect, isFalse);
      expect(subscription.isBanned, isTrue);
    });

    test('blocks unavailable subscription statuses', () {
      for (final status in const ['expired', 'banned']) {
        final subscription = activeSubscription.copyWith(subscriptionStatus: status);

        expect(subscription.canConnect, isFalse, reason: status);
      }
    });

    test('server canConnect cannot override local expiry', () {
      final expired = activeSubscription.copyWith(serverCanConnect: true, expiredAt: DateTime(2000));

      expect(expired.canConnect, isFalse);
    });

    // C-07：流量只做统计，任何取值都不得拦截连接（产品定义 v0.1 §3）。
    test('never blocks on traffic regardless of usage or status', () {
      const exhausted = UserSubscription(
        subscribeUrl: 'https://example.com/sub',
        membershipStatus: 'month',
        transferEnable: 100,
        upload: 100,
      );

      expect(exhausted.isTrafficExhausted, isTrue);
      expect(exhausted.canConnect, isTrue);
      expect(activeSubscription.copyWith(subscriptionStatus: 'traffic_exhausted').canConnect, isTrue);
      expect(
        activeSubscription.copyWith(serverCanConnect: true, transferEnable: 100, upload: 100).canConnect,
        isTrue,
      );
    });
  });

  // C-05：设备超限禁连，但不视为会员失效——不得触发清缓存/跳过节点同步。
  group('UserSubscription device limit', () {
    const paidSubscription = UserSubscription(
      subscribeUrl: 'https://example.com/sub',
      membershipStatus: 'month',
      planName: '月卡',
    );

    test('blocks only when online devices strictly exceed the limit', () {
      expect(paidSubscription.copyWith(onlineDevices: 4, maxDevices: 3).isDeviceLimitExceeded, isTrue);
      expect(paidSubscription.copyWith(onlineDevices: 3, maxDevices: 3).isDeviceLimitExceeded, isFalse);
      expect(paidSubscription.copyWith(onlineDevices: 1, maxDevices: 3).isDeviceLimitExceeded, isFalse);
    });

    test('degrades to allow when the backend omits device fields', () {
      expect(paidSubscription.isDeviceLimitExceeded, isFalse);
      expect(paidSubscription.copyWith(onlineDevices: 9).isDeviceLimitExceeded, isFalse);
      expect(paidSubscription.copyWith(maxDevices: 3).isDeviceLimitExceeded, isFalse);
      expect(paidSubscription.copyWith(onlineDevices: 9, maxDevices: 0).isDeviceLimitExceeded, isFalse);
    });

    test('keeps membership valid so node cache and sync are untouched', () {
      final overLimit = paidSubscription.copyWith(onlineDevices: 4, maxDevices: 3);

      expect(overLimit.isDeviceLimitExceeded, isTrue);
      expect(overLimit.canConnect, isTrue);
    });

    test('message carries current and limit counts', () {
      expect(paidSubscription.copyWith(onlineDevices: 4, maxDevices: 3).deviceLimitMessage, contains('当前 4'));
      expect(paidSubscription.copyWith(onlineDevices: 4, maxDevices: 3).deviceLimitMessage, contains('上限 3'));
      expect(paidSubscription.deviceLimitMessage, '登录设备已达上限');
    });
  });

  group('UserSubscription.displayMembershipLabel', () {
    test('uses BflyVPN names for default paid membership labels', () {
      for (final entry in const {'month': 'BflyVPN 月卡', 'quarter': 'BflyVPN 季卡', 'year': 'BflyVPN 年卡'}.entries) {
        final subscription = UserSubscription(
          subscribeUrl: 'https://example.com/sub',
          membershipStatus: entry.key,
          planId: 1,
        );

        expect(subscription.displayMembershipLabel, entry.value);
      }
    });
  });
}
