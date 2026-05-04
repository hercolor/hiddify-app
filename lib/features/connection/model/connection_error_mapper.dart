import 'package:hiddify/features/connection/model/connection_failure.dart';

abstract final class ConnectionErrorMapper {
  static const String networkTimeout = '当前网络波动，请稍后重试';
  static const String networkUnreachable = '当前网络不可用，请检查网络';
  static const String vpnPermissionRequired = '需要 VPN 权限才能加速';
  static const String notificationPermissionRequired = '需要通知权限以保持加速服务稳定运行';
  static const String authExpired = '登录已过期，请重新登录';
  static const String noNodes = '暂无可用节点，请联系客服';
  static const String coreStartFailed = '加速服务启动失败，请重试';
  static const String nodeUnstable = '当前节点不稳定，请切换节点';

  static String fromFailure(Object error) {
    if (error is MissingVpnPermission) {
      return vpnPermissionRequired;
    }
    if (error is MissingNotificationPermission) return notificationPermissionRequired;
    if (error is InvalidConfig || error is InvalidConfigOption || error is BackgroundCoreNotAvailable) {
      return coreStartFailed;
    }
    return fromText(error.toString());
  }

  static String fromText(String raw) {
    final text = raw.toLowerCase();
    if (text.contains('i/o timeout') || text.contains('timed out') || text.contains('timeout')) {
      return networkTimeout;
    }
    if (text.contains('network is unreachable') ||
        text.contains('network unreachable') ||
        text.contains('no route to host')) {
      return networkUnreachable;
    }
    if (text.contains('permission denied') ||
        text.contains('missing vpn permission') ||
        text.contains('requestvpnpermission')) {
      return vpnPermissionRequired;
    }
    if (text.contains('auth expired') ||
        text.contains('登录已过期') ||
        text.contains('unauthorized') ||
        text.contains('401') ||
        text.contains('403')) {
      return authExpired;
    }
    if (text.contains('no nodes') || text.contains('no active profile') || text.contains('暂无可用节点')) {
      return noNodes;
    }
    if (text.contains('core start failed') ||
        text.contains('failed to start core') ||
        text.contains('startservice') ||
        text.contains('start service') ||
        text.contains('start failed')) {
      return coreStartFailed;
    }
    if (text.contains('reconnect exhausted') || text.contains('node unstable')) {
      return nodeUnstable;
    }
    return coreStartFailed;
  }
}
