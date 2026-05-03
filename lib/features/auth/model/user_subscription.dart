class UserSubscription {
  const UserSubscription({
    required this.subscribeUrl,
    this.expiredAt,
    this.upload = 0,
    this.download = 0,
    this.transferEnable = 0,
  });

  final String subscribeUrl;
  final DateTime? expiredAt;
  final int upload;
  final int download;
  final int transferEnable;

  int get usedTraffic => upload + download;

  int? get remainingTraffic => transferEnable > 0 ? (transferEnable - usedTraffic).clamp(0, transferEnable) : null;

  bool get hasTrafficInfo => transferEnable > 0;

  UserSubscription copyWith({
    String? subscribeUrl,
    DateTime? expiredAt,
    int? upload,
    int? download,
    int? transferEnable,
  }) {
    return UserSubscription(
      subscribeUrl: subscribeUrl ?? this.subscribeUrl,
      expiredAt: expiredAt ?? this.expiredAt,
      upload: upload ?? this.upload,
      download: download ?? this.download,
      transferEnable: transferEnable ?? this.transferEnable,
    );
  }
}
