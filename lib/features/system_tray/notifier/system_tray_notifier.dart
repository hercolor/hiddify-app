import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/features/window/notifier/window_notifier.dart';
import 'package:hiddify/gen/assets.gen.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

part 'system_tray_notifier.g.dart';

@Riverpod(keepAlive: true)
class SystemTrayNotifier extends _$SystemTrayNotifier with TrayListener, AppLogger {
  bool listenerAdded = false;
  @override
  Future<void> build() async {
    assert(PlatformUtils.isDesktop);
    if (!listenerAdded) {
      trayManager.addListener(this);
      listenerAdded = true;
    }
    await _initializeTray();
  }

  Future<void> _initializeTray() async {
    final nodeSelection = ref.watch(clientNodeSelectionProvider);
    final clientState = ref.watch(clientConnectionStateProvider);
    final t = await ref.watch(translationsProvider.future);
    final selectedNodeName = _currentNodeName(nodeSelection);
    final connection = clientState.toCoreStatusHint();

    await trayManager.setIcon(_trayIconPath(connection), isTemplate: PlatformUtils.isMacOS);
    if (!PlatformUtils.isLinux) await trayManager.setToolTip(_trayTooltip(clientState, selectedNodeName));
    await trayManager.setContextMenu(_trayMenu(clientState, t, selectedNodeName));
  }

  Menu _trayMenu(ClientConnectionState state, Translations t, String selectedNodeName) => Menu(
    items: [
      MenuItem(key: 'title', label: Constants.appName, disabled: true),
      MenuItem(key: 'status', label: '状态：${state.trayStatusLabel}', disabled: true),
      MenuItem(key: 'dashboard', label: '打开应用'),
      MenuItem.separator(),
      MenuItem(key: 'current-node', label: '当前节点：${_safeTrayText(selectedNodeName)}', disabled: true),
      MenuItem.separator(),
      MenuItem(key: 'connection', label: state.trayActionLabel(t), disabled: state.isTrayActionDisabled),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: t.common.quit),
    ],
  );

  String _currentNodeName(AsyncValue<ClientNodeSelection> nodeSelection) =>
      nodeSelection.valueOrNull?.selectedNode?.name ?? '暂无可用节点';

  String _trayIconPath(ConnectionStatus status) {
    final isDarkMode = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    const images = Assets.images;
    final isWindows = PlatformUtils.isWindows;
    switch (status) {
      case Connected():
        return isWindows ? images.trayIconConnectedIco : images.trayIconConnectedPng.path;
      case Connecting():
      case Disconnecting():
        return isWindows ? images.trayIconDisconnectedIco : images.trayIconDisconnectedPng.path;
      case Disconnected():
        return isWindows
            ? isDarkMode
                  ? images.trayIconIco
                  : images.trayIconDarkIco
            : isDarkMode
            ? images.trayIconDarkPng.path
            : images.trayIconPng.path;
    }
  }

  String _trayTooltip(ClientConnectionState state, String selectedNodeName) {
    if (Platform.isMacOS) {
      windowManager.setBadgeLabel(state.phase == ClientConnectionPhase.connected ? 'ON' : '');
    }
    return '${Constants.appName} - ${state.trayStatusLabel} - ${_safeTrayText(selectedNodeName)}';
  }

  String _safeTrayText(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'https?://[^\s]+'), '***')
        .replaceAll(RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b'), '***');
    return sanitized.length > 48 ? '${sanitized.substring(0, 48)}…' : sanitized;
  }

  @override
  Future<void> onTrayMenuItemClick(MenuItem menuItem) async {
    // if (menuItem.key == 'dashboard') {
    //   await ref.read(windowNotifierProvider.notifier).open();
    // }
    if (menuItem.key == 'dashboard') {
      await ref.read(windowNotifierProvider.notifier).show();
    } else if (menuItem.key == 'connection') {
      await ref.read(connectionNotifierProvider.notifier).toggleConnection();
    } else if (menuItem.key == 'quit') {
      await ref.read(windowNotifierProvider.notifier).exit();
    }
  }

  @override
  Future<void> onTrayIconMouseDown() async {
    // if (Platform.isMacOS) {
    //   await trayManager.popUpContextMenu();
    // } else {
    //   await ref.read(windowNotifierProvider.notifier).hideOrShow();
    // }
    await ref.read(windowNotifierProvider.notifier).showOrHide();
  }

  @override
  Future<void> onTrayIconRightMouseDown() async {
    await trayManager.popUpContextMenu();
  }
}

extension _ClientConnectionTrayX on ClientConnectionState {
  String get trayStatusLabel => switch (phase) {
    ClientConnectionPhase.initializing => '初始化中',
    ClientConnectionPhase.loggedOut => '未登录',
    ClientConnectionPhase.disconnected => '未连接',
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting => '连接中',
    ClientConnectionPhase.connected => '已连接',
    ClientConnectionPhase.reconnecting => '重连中',
    ClientConnectionPhase.stopping => '停止中',
    ClientConnectionPhase.failed => '连接异常',
  };

  String trayActionLabel(Translations t) => switch (phase) {
    ClientConnectionPhase.connected => t.connection.disconnect,
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting => t.connection.connecting,
    ClientConnectionPhase.reconnecting => '正在重连',
    ClientConnectionPhase.stopping => t.connection.disconnecting,
    _ => t.connection.connect,
  };

  bool get isTrayActionDisabled => switch (phase) {
    ClientConnectionPhase.initializing ||
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting ||
    ClientConnectionPhase.reconnecting ||
    ClientConnectionPhase.stopping => true,
    _ => false,
  };

  ConnectionStatus toCoreStatusHint() => switch (phase) {
    ClientConnectionPhase.connected => const ConnectionStatus.connected(),
    ClientConnectionPhase.preparing ||
    ClientConnectionPhase.requestingVpnPermission ||
    ClientConnectionPhase.connecting ||
    ClientConnectionPhase.reconnecting => const ConnectionStatus.connecting(),
    ClientConnectionPhase.stopping => const ConnectionStatus.disconnecting(),
    _ => const ConnectionStatus.disconnected(),
  };
}

// @Riverpod(keepAlive: true)
// class SystemTrayNotifier extends _$SystemTrayNotifier with AppLogger {
//   @override
//   Future<void> build() async {
//     if (!PlatformUtils.isDesktop) return;

//     final activeProxy = await ref.watch(activeProxyNotifierProvider.future);
//     final delay = activeProxy.urlTestDelay;
//     final newConnectionStatus = delay > 0 && delay < 65000;
//     ConnectionStatus connection;
//     try {
//       connection = await ref.watch(connectionNotifierProvider.future);
//     } catch (e) {
//       loggy.warning("error getting connection status", e);
//       connection = const ConnectionStatus.disconnected();
//     }

//     final t = await ref.watch(translationsProvider.future);

//     var tooltip = Constants.appName;
//     final serviceMode = ref.watch(ConfigOptions.serviceMode);
//     if (connection is Disconnected) {
//       setIcon(connection);
//     } else if (newConnectionStatus) {
//       setIcon(const Connected());
//       tooltip = "$tooltip - ${connection.present(t)}";
//       if (newConnectionStatus) {
//         tooltip = "$tooltip : ${delay}ms";
//       } else {
//         tooltip = "$tooltip : -";
//       }
//       // else if (delay>1000)
//       //   SystemTrayNotifier.setIcon(timeout ? Disconnecting() : Connecting());
//     } else {
//       setIcon(const Disconnecting());
//       tooltip = "$tooltip - ${connection.present(t)}";
//     }
//     if (Platform.isMacOS) {
//       windowManager.setBadgeLabel("${delay}ms");
//     }
//     if (!Platform.isLinux) await trayManager.setToolTip(tooltip);

//     // final destinations = <(String label, String location)>[
//     //   (t.home.pageTitle, const HomeRoute().location),
//     //   (t.proxies.pageTitle, const ProfilesOverviewRoute().location),
//     //   (t.logs.title, const LogsOverviewRoute().location),
//     //   // (t.settings.pageTitle, const SettingsRoute().location),
//     //   (t.about.pageTitle, const AboutRoute().location),
//     // ];

//     // loggy.debug('updating system tray');

//     final menu = Menu(
//       items: [
//         MenuItem(
//           label: t.tray.dashboard,
//           onClick: (_) async {
//             await ref.read(windowNotifierProvider.notifier).open();
//           },
//         ),
//         MenuItem.separator(),
//         MenuItem.checkbox(
//           label: switch (connection) {
//             Disconnected() => t.tray.status.connect,
//             Connecting() => t.tray.status.connecting,
//             Connected() => t.tray.status.disconnect,
//             Disconnecting() => t.tray.status.disconnecting,
//           },
//           // checked: connection.isConnected,
//           checked: false,
//           disabled: connection.isSwitching,
//           onClick: (_) async {
//            await ref.read(connectionNotifierProvider.notifier).toggleConnection();
//          },
//        ),
//         MenuItem.separator(),
//         MenuItem(
//           label: t.config.serviceMode,
//           icon: Assets.images.trayIconIco,
//           disabled: true,
//         ),

//         ...ServiceMode.values.map(
//           (e) => MenuItem.checkbox(
//             checked: e == serviceMode,
//             key: e.name,
//             label: e.present(t),
//             onClick: (menuItem) async {
//               final newMode = ServiceMode.values.byName(menuItem.key!);
//               loggy.debug("switching service mode: [$newMode]");
//               await ref.read(ConfigOptions.serviceMode.notifier).update(newMode);
//             },
//           ),
//         ),

//         // MenuItem.submenu(
//         //   label: t.tray.open,
//         //   submenu: Menu(
//         //     items: [
//         //       ...destinations.map(
//         //         (e) => MenuItem(
//         //           label: e.$1,
//         //           onClick: (_) async {
//         //             await ref.read(windowNotifierProvider.notifier).open();
//         //             ref.read(routerProvider).go(e.$2);
//         //           },
//         //         ),
//         //       ),
//         //     ],
//         //   ),
//         // ),
//         MenuItem.separator(),
//         MenuItem(
//           label: t.tray.quit,
//           onClick: (_) async {
//             return ref.read(windowNotifierProvider.notifier).quit();
//           },
//         ),
//       ],
//     );

//     await trayManager.setContextMenu(menu);
//   }

//   static void setIcon(ConnectionStatus status) {
//     if (!PlatformUtils.isDesktop) return;
//     trayManager
//         .setIcon(
//           _trayIconPath(status),
//           isTemplate: Platform.isMacOS,
//         )
//         .asStream();
//   }

//   static String _trayIconPath(ConnectionStatus status) {
//     if (Platform.isWindows) {
//       final Brightness brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
//       final isDarkMode = brightness == Brightness.dark;
//       switch (status) {
//         case Connected():
//           return Assets.images.trayIconConnectedIco;
//         case Connecting():
//           return Assets.images.trayIconDisconnectedIco;
//         case Disconnecting():
//           return Assets.images.trayIconDisconnectedIco;
//         case Disconnected():
//           if (isDarkMode) {
//             return Assets.images.trayIconIco;
//           } else {
//             return Assets.images.trayIconDarkIco;
//           }
//       }
//     }
//     // const isDarkMode = false;
//     switch (status) {
//       case Connected():
//         return Assets.images.trayIconConnectedPng.path;
//       case Connecting():
//         return Assets.images.trayIconDisconnectedPng.path;
//       case Disconnecting():
//         return Assets.images.trayIconDisconnectedPng.path;
//       case Disconnected():
//         // if (isDarkMode) {
//         //   return Assets.images.trayIconDarkPng.path;
//         // } else {
//         //   return Assets.images.trayIconPng.path;
//         // }
//         return Assets.images.trayIconPng.path;
//     }
//     // return Assets.images.trayIconPng.path;
//   }
// }
