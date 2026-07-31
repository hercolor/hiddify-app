import 'dart:async';

import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/payment/data/payment_api_service.dart';
import 'package:hiddify/features/payment/model/payment_models.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// 进行中订单号。持久化是「回前台/重启后自动查单」兜底的前提（规范 §4.2）。
final pendingPaymentOrderProvider = PreferencesNotifier.create<String?, String?>(
  'payment.pending_trade_no',
  null,
  mapFrom: (value) => value == null || value.isEmpty ? null : value,
  mapTo: (value) => value ?? '',
);

final paymentNotifierProvider = StateNotifierProvider<PaymentNotifier, PaymentSessionState>(PaymentNotifier.new);

/// 支付闭环编排：下单 → 系统浏览器 → scheme/回前台唤回 → 查单 → 刷会员。
///
/// 规范：`docs/package-and-scheme-spec.md` §4。**订单状态一律以服务端查单为准**，
/// deep link 带的 `status` 只用来决定过渡文案。
class PaymentNotifier extends StateNotifier<PaymentSessionState> with InfraLogger {
  PaymentNotifier(this._ref) : super(PaymentSessionState.initial) {
    final pending = _ref.read(pendingPaymentOrderProvider);
    if (pending != null && pending.isNotEmpty) {
      state = state.copyWith(stage: PaymentStage.awaitingBrowser, tradeNo: pending);
    }
  }

  final Ref _ref;

  /// 单次查单的轮询上限。后端「开通中」通常几秒内落定，超过则转 unknown 交给兜底。
  static const _pollAttempts = 5;
  static const _pollInterval = Duration(seconds: 2);

  bool _confirming = false;

  /// 发起购买：创建订单 → 结账拿支付地址 → 系统浏览器打开。
  Future<void> startPurchase({required int planId, required String period, String? planName}) async {
    if (state.isBusy) {
      loggy.debug('purchase ignored, session busy');
      return;
    }
    final authData = _authData();
    if (authData == null) {
      _fail('请先登录账号');
      return;
    }

    state = PaymentSessionState(stage: PaymentStage.confirming, planName: planName, message: '正在创建订单');
    try {
      final api = await _ref.read(paymentApiServiceProvider.future);
      final tradeNo = await api.createOrder(authData, planId: planId, period: period);
      await _rememberPendingOrder(tradeNo);
      state = state.copyWith(tradeNo: tradeNo);

      final methods = await api.fetchPaymentMethods(authData);
      final checkout = await api.checkout(
        authData,
        tradeNo: tradeNo,
        methodId: methods.isEmpty ? null : methods.first.id,
      );
      DiagnosticEventBuffer.addSafe(
        'payment checkout ready: ${_orderTail(tradeNo)} redirect=${checkout.payUrl != null}',
      );

      if (checkout.settledWithoutRedirect) {
        await confirmPendingOrder();
        return;
      }

      final payUrl = checkout.payUrl;
      if (payUrl == null) {
        _fail('发起支付失败，请稍后重试');
        return;
      }
      final launched = await UriUtils.tryLaunch(Uri.parse(payUrl));
      if (!launched) {
        _fail('无法打开浏览器，请稍后重试');
        return;
      }
      state = state.copyWith(stage: PaymentStage.awaitingBrowser, message: '请在浏览器完成支付');
    } catch (error, stackTrace) {
      loggy.warning('purchase failed', error, stackTrace);
      DiagnosticEventBuffer.addSafe('payment purchase failed');
      _fail(_failureMessage(error, fallback: '发起支付失败，请稍后重试'));
    }
  }

  /// 处理 `bflyvpn://` 唤起（规范 §3.4）。
  Future<void> handleDeepLink(BflyDeepLink link) async {
    DiagnosticEventBuffer.addSafe('payment ${link.safeSummary}');
    switch (link.action) {
      case BflyLinkAction.payResult:
        await _handlePayResult(link);
      case BflyLinkAction.refresh:
        await _refreshMembership();
      case BflyLinkAction.unknown:
        loggy.debug('unknown deep link ignored');
    }
  }

  Future<void> _handlePayResult(BflyDeepLink link) async {
    final tradeNo = link.orderId ?? state.tradeNo ?? _ref.read(pendingPaymentOrderProvider);
    // 无 order_id 也要触发一次刷新，并提示结果未知（规范 §3.4 第 3 条）。
    if (tradeNo == null || tradeNo.isEmpty) {
      await _refreshMembership();
      state = state.copyWith(stage: PaymentStage.unknown, message: '支付结果未知，请稍后刷新');
      return;
    }
    final orderId = link.orderId;
    if (orderId != null) await _rememberPendingOrder(orderId);
    await _confirmOrder(tradeNo, hintCancelled: link.looksCancelled);
  }

  /// 回前台 / 手动「刷新支付状态」兜底（规范 §4.2）。
  Future<void> confirmPendingOrder({bool silent = false}) async {
    final tradeNo = state.tradeNo ?? _ref.read(pendingPaymentOrderProvider);
    if (tradeNo == null || tradeNo.isEmpty) {
      if (!silent) await _refreshMembership();
      return;
    }
    await _confirmOrder(tradeNo);
  }

  /// 用户主动放弃当前订单，回到可重新选择套餐的状态。
  Future<void> dismissSession() async {
    await _rememberPendingOrder(null);
    state = PaymentSessionState.initial;
  }

  Future<void> _confirmOrder(String tradeNo, {bool hintCancelled = false}) async {
    if (_confirming) {
      loggy.debug('confirm ignored, already running');
      return;
    }
    final authData = _authData();
    if (authData == null) {
      // 未登录时被 scheme 唤起：丢弃订单会话，登录后由套餐页重新发起（规范 P-18）。
      await _rememberPendingOrder(null);
      state = PaymentSessionState.initial;
      return;
    }

    _confirming = true;
    state = state.copyWith(stage: PaymentStage.confirming, tradeNo: tradeNo, message: '正在确认支付结果');
    try {
      final api = await _ref.read(paymentApiServiceProvider.future);
      PaymentOrder? order;
      for (var attempt = 0; attempt < _pollAttempts; attempt++) {
        order = await api.fetchOrder(authData, tradeNo: tradeNo);
        if (order.status.isTerminal) break;
        if (attempt < _pollAttempts - 1) await Future<void>.delayed(_pollInterval);
      }
      DiagnosticEventBuffer.addSafe('payment confirm: ${order?.safeSummary ?? 'no order'}');

      if (order != null && order.status.isPaid) {
        await _rememberPendingOrder(null);
        await _refreshMembership();
        state = state.copyWith(stage: PaymentStage.paid, message: '会员已生效', clearTradeNo: true);
        _ref.read(inAppNotificationControllerProvider).showSuccessToast('会员已生效，可以连接');
        return;
      }
      if (order != null && order.status == PaymentOrderStatus.cancelled) {
        await _rememberPendingOrder(null);
        state = state.copyWith(stage: PaymentStage.cancelled, message: '订单已取消，可重新选择套餐', clearTradeNo: true);
        return;
      }
      // 仍是 pending：保留订单，交给回前台/手动刷新继续兜底。
      state = state.copyWith(
        stage: hintCancelled ? PaymentStage.cancelled : PaymentStage.unknown,
        message: hintCancelled ? '支付已取消，可重新发起' : '支付状态确认中，可稍后刷新或联系客服',
      );
      if (hintCancelled) await _rememberPendingOrder(null);
    } catch (error, stackTrace) {
      loggy.warning('order confirm failed', error, stackTrace);
      DiagnosticEventBuffer.addSafe('payment confirm failed: ${_orderTail(tradeNo)}');
      state = state.copyWith(stage: PaymentStage.unknown, message: '支付状态确认失败，请稍后刷新');
    } finally {
      _confirming = false;
    }
  }

  Future<void> _refreshMembership() async {
    try {
      await _ref
          .read(authNotifierProvider.notifier)
          .refreshSubscription(showSuccessToast: false, showFailureToast: false);
    } catch (error, stackTrace) {
      loggy.debug('membership refresh after payment failed', error, stackTrace);
    }
  }

  Future<void> _rememberPendingOrder(String? tradeNo) async {
    await _ref.read(pendingPaymentOrderProvider.notifier).update(tradeNo);
  }

  String? _authData() {
    final authState = _ref.read(authNotifierProvider).valueOrNull;
    if (authState?.status != AuthStatus.loggedIn) return null;
    final authData = authState?.session?.authData.trim();
    return authData == null || authData.isEmpty ? null : authData;
  }

  void _fail(String message) {
    state = state.copyWith(stage: PaymentStage.failed, message: message);
    _ref.read(inAppNotificationControllerProvider).showErrorToast(message);
  }

  String _orderTail(String tradeNo) =>
      'order=***${tradeNo.length <= 6 ? tradeNo : tradeNo.substring(tradeNo.length - 6)}';

  /// 只透传后端明确的业务提示，其余一律用产品文案，避免把技术错误抛给用户。
  String _failureMessage(Object error, {required String fallback}) =>
      error is AuthServerMessageFailure ? error.message : fallback;
}
