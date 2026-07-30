class UserSubscription {
  const UserSubscription({
    required this.subscribeUrl,
    this.expiredAt,
    this.upload = 0,
    this.download = 0,
    this.transferEnable = 0,
    this.planId,
    this.planName,
    this.membershipStatus,
    this.membershipLabel,
    this.subscriptionStatus,
    this.serverCanConnect,
    this.onlineDevices,
    this.maxDevices,
    this.customerService,
  });

  final String subscribeUrl;
  final DateTime? expiredAt;
  final int upload;
  final int download;
  final int transferEnable;
  final int? planId;
  final String? planName;
  final String? membershipStatus;
  final String? membershipLabel;
  final String? subscriptionStatus;
  final bool? serverCanConnect;
  final int? onlineDevices;
  final int? maxDevices;
  final String? customerService;

  int get usedTraffic => upload + download;

  int? get remainingTraffic => transferEnable > 0 ? (transferEnable - usedTraffic).clamp(0, transferEnable) : null;

  bool get hasTrafficInfo => transferEnable > 0;

  bool get isExpired => expiredAt != null && !expiredAt!.isAfter(DateTime.now());

  /// 流量仅用于统计展示，不参与连接门禁（产品定义 v0.1 §3）。
  bool get isTrafficExhausted => remainingTraffic != null && remainingTraffic! <= 0;

  String? get _normalizedMembershipStatus => membershipStatus?.trim().toLowerCase();

  String? get _normalizedSubscriptionStatus => subscriptionStatus?.trim().toLowerCase();

  bool get isNormalUser => _normalizedMembershipStatus == 'normal';

  bool get isBanned => _normalizedSubscriptionStatus == 'banned';

  bool get isSubscriptionExpired =>
      _normalizedMembershipStatus == 'expired' || _normalizedSubscriptionStatus == 'expired' || isExpired;

  /// 只有后端同时返回在线设备数与设备上限时才做设备门禁；字段缺失按放行处理。
  bool get hasDeviceLimitInfo => onlineDevices != null && (maxDevices ?? 0) > 0;

  /// 严格超出上限才拦截；等于上限视为当前设备已计入，不拦。
  bool get isDeviceLimitExceeded => hasDeviceLimitInfo && onlineDevices! > maxDevices!;

  String get deviceLimitMessage => hasDeviceLimitInfo
      ? '登录设备已达上限（当前 $onlineDevices / 上限 $maxDevices）'
      : '登录设备已达上限';

  bool get isMembershipUnavailable {
    final membership = _normalizedMembershipStatus;
    final subscription = _normalizedSubscriptionStatus;
    return membership == 'normal' || membership == 'expired' || subscription == 'expired' || subscription == 'banned';
  }

  bool get hasActiveMembership =>
      (const {'month', 'quarter', 'year'}.contains(_normalizedMembershipStatus) ||
          (membershipStatus == null && planName?.trim().isNotEmpty == true)) &&
      !isExpired;

  String get displayMembershipLabel {
    final label = membershipLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (isSubscriptionExpired) return '会员到期';
    if (isNormalUser || planId == null) return '普通用户';
    return switch (_normalizedMembershipStatus) {
      'month' => 'BflyVPN 月卡',
      'quarter' => 'BflyVPN 季卡',
      'year' => 'BflyVPN 年卡',
      _ => planName?.trim().isNotEmpty == true ? planName!.trim() : '普通用户',
    };
  }

  /// 会员资格门禁：只看到期时间与账号状态，不看流量、不看设备数。
  ///
  /// 设备门禁由 [isDeviceLimitExceeded] 单独在连接时判断——设备超限是瞬时状态，
  /// 不应触发清缓存或跳过节点同步。
  bool get canConnect {
    if (isMembershipUnavailable) return false;
    if (serverCanConnect != null) {
      return serverCanConnect! && !isSubscriptionExpired;
    }
    return !isSubscriptionExpired && hasActiveMembership;
  }

  UserSubscription copyWith({
    String? subscribeUrl,
    DateTime? expiredAt,
    int? upload,
    int? download,
    int? transferEnable,
    int? planId,
    String? planName,
    String? membershipStatus,
    String? membershipLabel,
    String? subscriptionStatus,
    bool? serverCanConnect,
    int? onlineDevices,
    int? maxDevices,
    String? customerService,
  }) {
    return UserSubscription(
      subscribeUrl: subscribeUrl ?? this.subscribeUrl,
      expiredAt: expiredAt ?? this.expiredAt,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      transferEnable: transferEnable ?? this.transferEnable,
      planId: planId ?? this.planId,
      planName: planName ?? this.planName,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      membershipLabel: membershipLabel ?? this.membershipLabel,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      serverCanConnect: serverCanConnect ?? this.serverCanConnect,
      onlineDevices: onlineDevices ?? this.onlineDevices,
      maxDevices: maxDevices ?? this.maxDevices,
      customerService: customerService ?? this.customerService,
    );
  }
}
