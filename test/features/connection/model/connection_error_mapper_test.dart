import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/features/connection/model/connection_error_mapper.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';

void main() {
  group('ConnectionErrorMapper', () {
    test('maps timeout errors to readable network message', () {
      expect(ConnectionErrorMapper.fromText('dial tcp: i/o timeout'), '当前网络波动，请稍后重试');
      expect(ConnectionErrorMapper.fromText('request timed out'), '当前网络波动，请稍后重试');
    });

    test('maps unreachable network errors', () {
      expect(ConnectionErrorMapper.fromText('IPv6 direct network is unreachable'), '当前网络不可用，请检查网络');
      expect(ConnectionErrorMapper.fromText('no route to host'), '当前网络不可用，请检查网络');
    });

    test('maps permission errors to VPN permission message', () {
      expect(ConnectionErrorMapper.fromText('permission denied'), '需要 VPN 权限才能加速');
      expect(ConnectionErrorMapper.fromFailure(const ConnectionFailure.missingVpnPermission()), '需要 VPN 权限才能加速');
      expect(
        ConnectionErrorMapper.fromFailure(const ConnectionFailure.missingNotificationPermission()),
        '需要通知权限以保持加速服务稳定运行',
      );
    });

    test('maps auth expired and HTTP auth failures', () {
      expect(ConnectionErrorMapper.fromText('auth expired'), '登录已过期，请重新登录');
      expect(ConnectionErrorMapper.fromText('HTTP 401 unauthorized'), '登录已过期，请重新登录');
      expect(ConnectionErrorMapper.fromText('HTTP 403 forbidden'), '登录已过期，请重新登录');
    });

    test('maps empty node errors', () {
      expect(ConnectionErrorMapper.fromText('no nodes'), '暂无可用节点，请联系客服');
      expect(ConnectionErrorMapper.fromText('no active profile'), '暂无可用节点，请联系客服');
    });

    test('maps core start failures without exposing raw core text', () {
      expect(ConnectionErrorMapper.fromText('failed to start core START_SERVICE'), '加速服务启动失败，请重试');
      expect(ConnectionErrorMapper.fromFailure(const ConnectionFailure.backgroundCoreNotAvailable()), '加速服务启动失败，请重试');
    });

    test('maps exhausted reconnect attempts', () {
      expect(ConnectionErrorMapper.fromText('reconnect exhausted'), '当前节点不稳定，请切换节点');
    });
  });
}
