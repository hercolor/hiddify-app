import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/payment/model/payment_models.dart';

void main() {
  group('BflyDeepLink.tryParse', () {
    // P-11：支付成功回跳。
    test('parses pay result with order id and status', () {
      final link = BflyDeepLink.tryParse('bflyvpn://pay/result?order_id=ORDER123&status=success');

      expect(link, isNotNull);
      expect(link!.action, BflyLinkAction.payResult);
      expect(link.orderId, 'ORDER123');
      expect(link.status, 'success');
      expect(link.looksCancelled, isFalse);
    });

    // P-12：取消回跳。
    test('marks cancel status', () {
      final link = BflyDeepLink.tryParse('bflyvpn://pay/result?order_id=ORDER123&status=cancel');

      expect(link!.looksCancelled, isTrue);
    });

    test('accepts trade_no as the order id alias', () {
      final link = BflyDeepLink.tryParse('bflyvpn://pay/result?trade_no=T99');

      expect(link!.orderId, 'T99');
    });

    test('parses generic refresh links', () {
      expect(BflyDeepLink.tryParse('bflyvpn://app/refresh')!.action, BflyLinkAction.refresh);
      expect(BflyDeepLink.tryParse('bflyvpn://app/refresh?reason=pay')!.action, BflyLinkAction.refresh);
    });

    test('maps unrecognised hosts to unknown instead of failing', () {
      expect(BflyDeepLink.tryParse('bflyvpn://whatever/else')!.action, BflyLinkAction.unknown);
    });

    test('rejects foreign schemes', () {
      expect(BflyDeepLink.tryParse('https://api.example.com/pay/result'), isNull);
      expect(BflyDeepLink.tryParse('hiddify://import/x'), isNull);
      expect(BflyDeepLink.matches('bflyvpn://pay/result'), isTrue);
    });

    test('is case insensitive on scheme, host and path', () {
      final link = BflyDeepLink.tryParse('BFLYVPN://PAY/RESULT?ORDER_ID=A1&STATUS=SUCCESS');

      expect(link!.action, BflyLinkAction.payResult);
      expect(link.orderId, 'A1');
      expect(link.status, 'success');
    });

    test('drops unrecognised status values from diagnostics', () {
      final link = BflyDeepLink.tryParse('bflyvpn://pay/result?order_id=ORDER123&status=SECRET%0Afake-log');

      expect(link!.status, isNull);
      expect(link.safeSummary, isNot(contains('SECRET')));
      expect(link.safeSummary, isNot(contains('fake-log')));
    });

    test('drops unsafe order ids from diagnostics', () {
      final link = BflyDeepLink.tryParse('bflyvpn://pay/result?order_id=SECRET%0Afake-log&status=success');

      expect(link!.orderId, isNull);
      expect(link.safeSummary, isNot(contains('SECRET')));
      expect(link.safeSummary, isNot(contains('fake-log')));
    });

    // P-17：scheme 含禁止字段时必须忽略，且不得进入摘要/日志。
    test('drops forbidden credential params and keeps them out of the log summary', () {
      final link = BflyDeepLink.tryParse(
        'bflyvpn://pay/result?order_id=ORDER123&status=success'
        '&authData=SECRET&token=SECRET&subscribe_url=https%3A%2F%2Fsub.example.com%2Fs%2Fabc',
      );

      expect(link!.orderId, 'ORDER123');
      expect(link.safeSummary, isNot(contains('SECRET')));
      expect(link.safeSummary, isNot(contains('sub.example.com')));
      // 摘要只保留订单号尾段，不含完整订单号。
      expect(link.safeSummary, contains('***'));
      expect(link.safeSummary, isNot(contains('ORDER123')));
    });

    // 规范 §3.4 第 3 条：无 order_id 仍需可解析，由上层触发一次会员刷新。
    test('keeps pay result parseable without an order id', () {
      final link = BflyDeepLink.tryParse('bflyvpn://pay/result');

      expect(link!.action, BflyLinkAction.payResult);
      expect(link.orderId, isNull);
    });
  });

  group('PaymentOrderStatus.fromCode', () {
    test('maps XBoard order codes', () {
      expect(PaymentOrderStatus.fromCode(0), PaymentOrderStatus.pending);
      expect(PaymentOrderStatus.fromCode(1), PaymentOrderStatus.processing);
      expect(PaymentOrderStatus.fromCode(2), PaymentOrderStatus.cancelled);
      expect(PaymentOrderStatus.fromCode(3), PaymentOrderStatus.completed);
      expect(PaymentOrderStatus.fromCode(4), PaymentOrderStatus.completed);
      expect(PaymentOrderStatus.fromCode(null), PaymentOrderStatus.unknown);
      expect(PaymentOrderStatus.fromCode(99), PaymentOrderStatus.unknown);
    });

    test('keeps processing non-terminal until the server completes the order', () {
      expect(PaymentOrderStatus.processing.isPaid, isFalse);
      expect(PaymentOrderStatus.processing.isTerminal, isFalse);
      expect(PaymentOrderStatus.completed.isPaid, isTrue);
      expect(PaymentOrderStatus.pending.isPaid, isFalse);
      expect(PaymentOrderStatus.cancelled.isPaid, isFalse);
      expect(PaymentOrderStatus.unknown.isTerminal, isFalse);
    });
  });

  group('PaymentSessionState', () {
    test('flags sessions that still need a fallback query', () {
      const awaiting = PaymentSessionState(stage: PaymentStage.awaitingBrowser, tradeNo: 'T1');
      const unknown = PaymentSessionState(stage: PaymentStage.unknown, tradeNo: 'T1');
      const failedAfterOrder = PaymentSessionState(stage: PaymentStage.failed, tradeNo: 'T1');
      const paid = PaymentSessionState(stage: PaymentStage.paid);

      expect(awaiting.hasUnsettledOrder, isTrue);
      expect(unknown.hasUnsettledOrder, isTrue);
      expect(failedAfterOrder.hasUnsettledOrder, isTrue);
      expect(paid.hasUnsettledOrder, isFalse);
      expect(PaymentSessionState.initial.hasUnsettledOrder, isFalse);
    });

    test('clears fields explicitly rather than through null coalescing', () {
      const state = PaymentSessionState(stage: PaymentStage.confirming, tradeNo: 'T1', message: 'x');

      expect(state.copyWith(clearTradeNo: true).tradeNo, isNull);
      expect(state.copyWith(clearMessage: true).message, isNull);
      expect(state.copyWith(stage: PaymentStage.paid).tradeNo, 'T1');
    });
  });

  group('maskedOrderId', () {
    test('never exposes a short order id in full', () {
      expect(maskedOrderId('T99'), '***');
      expect(maskedOrderId('ORDER123'), '***DER123');
      expect(maskedOrderId('SECRET\nfake-log'), '***ke-log');
      expect(maskedOrderId(null), 'none');
    });
  });
}
