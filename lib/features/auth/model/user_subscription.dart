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

  bool get isTrafficExhausted => remainingTraffic != null && remainingTraffic! <= 0;

  String? get _normalizedMembershipStatus => membershipStatus?.trim().toLowerCase();

  String? get _normalizedSubscriptionStatus => subscriptionStatus?.trim().toLowerCase();

  bool get isNormalUser => _normalizedMembershipStatus == 'normal';

  bool get isBanned => _normalizedSubscriptionStatus == 'banned';

  bool get isSubscriptionExpired =>
      _normalizedMembershipStatus == 'expired' || _normalizedSubscriptionStatus == 'expired' || isExpired;

  bool get isTrafficUnavailable => isTrafficExhausted || _normalizedSubscriptionStatus == 'traffic_exhausted';

  bool get isMembershipUnavailable {
    final membership = _normalizedMembershipStatus;
    final subscription = _normalizedSubscriptionStatus;
    return membership == 'normal' ||
        membership == 'expired' ||
        subscription == 'expired' ||
        subscription == 'banned' ||
        subscription == 'traffic_exhausted';
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

  bool get canConnect {
    if (isMembershipUnavailable) return false;
    if (serverCanConnect != null) {
      return serverCanConnect! && !isSubscriptionExpired && !isTrafficUnavailable;
    }
    return !isSubscriptionExpired && !isTrafficUnavailable && hasActiveMembership;
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
