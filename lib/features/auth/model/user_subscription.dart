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

  bool get isNormalUser => membershipStatus == 'normal';

  bool get hasActiveMembership =>
      (const {'month', 'quarter', 'year'}.contains(membershipStatus) ||
          (membershipStatus == null && planName?.trim().isNotEmpty == true)) &&
      !isExpired;

  String get displayMembershipLabel {
    final label = membershipLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    if (membershipStatus == 'expired' || isExpired) return '会员到期';
    if (membershipStatus == 'normal' || planId == null) return '普通用户';
    return switch (membershipStatus) {
      'month' => '蝴蝶月卡',
      'quarter' => '蝴蝶季卡',
      'year' => '蝴蝶年卡',
      _ => planName?.trim().isNotEmpty == true ? planName!.trim() : '普通用户',
    };
  }

  bool get canConnect {
    if (serverCanConnect != null) return serverCanConnect! && !isExpired && !isTrafficExhausted;
    return !isNormalUser && !isExpired && !isTrafficExhausted;
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
