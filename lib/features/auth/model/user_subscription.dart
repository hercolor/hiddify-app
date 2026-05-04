class UserSubscription {
  const UserSubscription({
    required this.subscribeUrl,
    this.expiredAt,
    this.upload = 0,
    this.download = 0,
    this.transferEnable = 0,
    this.planName,
    this.onlineDevices,
    this.maxDevices,
    this.customerService,
  });

  final String subscribeUrl;
  final DateTime? expiredAt;
  final int upload;
  final int download;
  final int transferEnable;
  final String? planName;
  final int? onlineDevices;
  final int? maxDevices;
  final String? customerService;

  int get usedTraffic => upload + download;

  int? get remainingTraffic => transferEnable > 0 ? (transferEnable - usedTraffic).clamp(0, transferEnable) : null;

  bool get hasTrafficInfo => transferEnable > 0;

  UserSubscription copyWith({
    String? subscribeUrl,
    DateTime? expiredAt,
    int? upload,
    int? download,
    int? transferEnable,
    String? planName,
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
      planName: planName ?? this.planName,
      onlineDevices: onlineDevices ?? this.onlineDevices,
      maxDevices: maxDevices ?? this.maxDevices,
      customerService: customerService ?? this.customerService,
    );
  }
}
