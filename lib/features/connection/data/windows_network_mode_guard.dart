import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/singbox/model/singbox_config_option.dart';
import 'package:hiddify/utils/custom_loggers.dart';

class WindowsNetworkModeGuard with InfraLogger {
  static const networkComponentMissingMarker = 'WINDOWS_NETWORK_COMPONENT_MISSING';

  Future<Either<ConnectionFailure, WindowsNetworkModeSnapshot>> ensureReady(SingboxConfigOption options) async {
    final snapshot = await inspect(options);
    loggy.debug(
      'windows network mode: '
      'mode=${snapshot.mode}, '
      'enableTun=${snapshot.enableTun}, '
      'setSystemProxy=${snapshot.setSystemProxy}, '
      'mixedPort=${snapshot.mixedPort}, '
      'wintun=${snapshot.usesWintun}, '
      'wintunDriverInstalled=${snapshot.wintunDriverInstalled}, '
      'isAdmin=${snapshot.isAdministrator}',
    );

    if (!Platform.isWindows || !snapshot.enableTun) {
      return right(snapshot);
    }

    if (!snapshot.wintunDriverInstalled) {
      return left(const ConnectionFailure.backgroundCoreNotAvailable(networkComponentMissingMarker));
    }

    if (!snapshot.isAdministrator) {
      return left(const ConnectionFailure.missingPrivilege());
    }

    return right(snapshot);
  }

  Future<WindowsNetworkModeSnapshot> inspect(SingboxConfigOption options) async {
    final enableTun = options.enableTun;
    final setSystemProxy = options.setSystemProxy;
    final mode = enableTun
        ? WindowsNetworkMode.tun
        : setSystemProxy
        ? WindowsNetworkMode.systemProxy
        : WindowsNetworkMode.mixedOnly;

    if (!Platform.isWindows) {
      return WindowsNetworkModeSnapshot(
        mode: mode,
        enableTun: enableTun,
        setSystemProxy: setSystemProxy,
        mixedPort: options.mixedPort,
        usesWintun: false,
        wintunDriverInstalled: false,
        isAdministrator: false,
      );
    }

    final usesWintun = enableTun;
    final wintunDriverInstalled = usesWintun && await _isWintunDriverInstalled();
    final isAdministrator = await _isRunningAsAdministrator();

    return WindowsNetworkModeSnapshot(
      mode: mode,
      enableTun: enableTun,
      setSystemProxy: setSystemProxy,
      mixedPort: options.mixedPort,
      usesWintun: usesWintun,
      wintunDriverInstalled: wintunDriverInstalled,
      isAdministrator: isAdministrator,
    );
  }

  Future<bool> _isWintunDriverInstalled() async {
    final windir = Platform.environment['WINDIR'] ?? r'C:\Windows';
    final driverFile = File(r'$windir\System32\drivers\wintun.sys'.replaceFirst(r'$windir', windir));
    if (await driverFile.exists()) return true;

    final scResult = await _runQuietly('sc.exe', const ['query', 'wintun']);
    if (scResult?.exitCode == 0) return true;

    final output = '${scResult?.stdout ?? ''}\n${scResult?.stderr ?? ''}'.toLowerCase();
    return output.contains('wintun') && !output.contains('does not exist') && !output.contains('1060');
  }

  Future<bool> _isRunningAsAdministrator() async {
    final result = await _runQuietly('net.exe', const ['session']);
    return result?.exitCode == 0;
  }

  Future<ProcessResult?> _runQuietly(String executable, List<String> arguments) async {
    try {
      return await Process.run(executable, arguments).timeout(const Duration(seconds: 2));
    } catch (error, stackTrace) {
      loggy.debug('windows network check command skipped: $executable', error, stackTrace);
      return null;
    }
  }
}

enum WindowsNetworkMode { tun, systemProxy, mixedOnly }

class WindowsNetworkModeSnapshot {
  const WindowsNetworkModeSnapshot({
    required this.mode,
    required this.enableTun,
    required this.setSystemProxy,
    required this.mixedPort,
    required this.usesWintun,
    required this.wintunDriverInstalled,
    required this.isAdministrator,
  });

  final WindowsNetworkMode mode;
  final bool enableTun;
  final bool setSystemProxy;
  final int mixedPort;
  final bool usesWintun;
  final bool wintunDriverInstalled;
  final bool isAdministrator;
}
