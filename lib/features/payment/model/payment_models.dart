/// 支付会话、订单与 deep link 模型。
///
/// 契约见 `docs/package-and-scheme-spec.md` §3–§5：
/// - 订单状态 **以服务端查单为准**，scheme 携带的 `status` 仅用于 UI 过渡文案。
/// - scheme query 中的敏感字段一律丢弃，且不进日志。
library;

/// 客户端支付会话状态机（规范 §4.3）。
enum PaymentStage { idle, awaitingBrowser, confirming, paid, failed, cancelled, unknown }

class PaymentSessionState {
  const PaymentSessionState({this.stage = PaymentStage.idle, this.tradeNo, this.planName, this.message});

  static const initial = PaymentSessionState();

  final PaymentStage stage;
  final String? tradeNo;
  final String? planName;
  final String? message;

  /// 进行中：用于按钮防抖，避免并发打爆查单接口。
  bool get isBusy => stage == PaymentStage.awaitingBrowser || stage == PaymentStage.confirming;

  /// 是否还存在需要兜底查单的订单（规范 §4.2）。
  bool get hasUnsettledOrder =>
      tradeNo != null &&
      (stage == PaymentStage.awaitingBrowser || stage == PaymentStage.confirming || stage == PaymentStage.unknown);

  PaymentSessionState copyWith({
    PaymentStage? stage,
    String? tradeNo,
    bool clearTradeNo = false,
    String? planName,
    bool clearPlanName = false,
    String? message,
    bool clearMessage = false,
  }) {
    return PaymentSessionState(
      stage: stage ?? this.stage,
      tradeNo: clearTradeNo ? null : tradeNo ?? this.tradeNo,
      planName: clearPlanName ? null : planName ?? this.planName,
      message: clearMessage ? null : message ?? this.message,
    );
  }
}

/// XBoard 订单状态。数值口径：0 待支付 / 1 开通中 / 2 已取消 / 3 已完成 / 4 已折抵。
enum PaymentOrderStatus {
  pending,
  processing,
  cancelled,
  completed,
  unknown;

  /// 已支付：`processing` 表示后端已收款、正在开通，对用户等价于成功。
  bool get isPaid => this == PaymentOrderStatus.completed || this == PaymentOrderStatus.processing;

  bool get isTerminal => isPaid || this == PaymentOrderStatus.cancelled;

  static PaymentOrderStatus fromCode(int? code) => switch (code) {
    0 => PaymentOrderStatus.pending,
    1 => PaymentOrderStatus.processing,
    2 => PaymentOrderStatus.cancelled,
    3 || 4 => PaymentOrderStatus.completed,
    _ => PaymentOrderStatus.unknown,
  };
}

class PaymentOrder {
  const PaymentOrder({required this.tradeNo, required this.status, this.planId, this.totalAmountCents});

  final String tradeNo;
  final PaymentOrderStatus status;
  final int? planId;
  final int? totalAmountCents;

  /// 诊断用摘要：只暴露订单号后 6 位与状态，不带金额以外的用户信息。
  String get safeSummary => 'order=***${tradeNo.length <= 6 ? tradeNo : tradeNo.substring(tradeNo.length - 6)} '
      'status=${status.name}';
}

/// 支付下单结果：拿到 `pay_url` 走系统浏览器；余额直付时后端可能直接返回已支付。
class PaymentCheckout {
  const PaymentCheckout({required this.tradeNo, this.payUrl, this.settledWithoutRedirect = false});

  final String tradeNo;
  final String? payUrl;
  final bool settledWithoutRedirect;
}

enum BflyLinkAction { payResult, refresh, unknown }

/// `bflyvpn://` deep link（规范 §3）。
class BflyDeepLink {
  const BflyDeepLink({required this.action, this.orderId, this.status});

  static const scheme = 'bflyvpn';

  /// 明确禁止出现在 query 中的字段（规范 §3.3）。解析阶段直接丢弃，绝不落日志。
  static const _forbiddenParams = {
    'authdata',
    'auth_data',
    'token',
    'access_token',
    'password',
    'passwd',
    'subscribe_url',
    'subscribeurl',
    'sub_url',
  };

  final BflyLinkAction action;
  final String? orderId;
  final String? status;

  static bool matches(String raw) => Uri.tryParse(raw.trim())?.scheme.toLowerCase() == scheme;

  static BflyDeepLink? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || uri.scheme.toLowerCase() != scheme) return null;

    final params = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      final key = entry.key.toLowerCase();
      if (_forbiddenParams.contains(key)) continue;
      params[key] = entry.value;
    }

    final host = uri.host.toLowerCase();
    final path = uri.path.toLowerCase().replaceAll(RegExp(r'/+$'), '');
    final orderId = _firstNonEmpty(params, const ['order_id', 'orderid', 'trade_no', 'tradeno']);
    final status = _firstNonEmpty(params, const ['status']);

    if (host == 'pay' && (path == '/result' || path.isEmpty)) {
      return BflyDeepLink(action: BflyLinkAction.payResult, orderId: orderId, status: status?.toLowerCase());
    }
    if (host == 'app' && (path == '/refresh' || path.isEmpty)) {
      return const BflyDeepLink(action: BflyLinkAction.refresh);
    }
    return const BflyDeepLink(action: BflyLinkAction.unknown);
  }

  /// 用户取消：仅作为 UI 提示，最终状态仍以服务端查单为准。
  bool get looksCancelled => status == 'cancel' || status == 'cancelled';

  /// 脱敏摘要，可安全写入诊断缓冲。
  String get safeSummary {
    final order = orderId;
    final tail = order == null || order.isEmpty
        ? 'none'
        : '***${order.length <= 6 ? order : order.substring(order.length - 6)}';
    return 'deeplink action=${action.name} order=$tail status=${status ?? 'none'}';
  }

  static String? _firstNonEmpty(Map<String, String> params, List<String> keys) {
    for (final key in keys) {
      final value = params[key]?.trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }
}
