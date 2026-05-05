import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/client_connection_state.dart';
import 'package:hiddify/features/connection/model/connection_error_mapper.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'connection_notifier.g.dart';

final clientConnectionStateProvider = StateProvider<ClientConnectionState>(
  (ref) => const ClientConnectionState.initializing(),
);

@Riverpod(keepAlive: true)
class ConnectionNotifier extends _$ConnectionNotifier with AppLogger {
  static const _reconnectDelays = [Duration(seconds: 1), Duration(seconds: 3), Duration(seconds: 5)];

  bool _userRequestedConnection = false;
  bool _manualDisconnecting = false;
  bool _vpnPermissionRequestedForAttempt = false;
  bool _autoReconnectRunning = false;
  int _reconnectAttempts = 0;
  ConnectionStatus _lastCoreStatus = const ConnectionStatus.disconnected();
  ClientConnectionState _clientState = const ClientConnectionState.initializing();

  @override
  Stream<ConnectionStatus> build() async* {
    if (Platform.isIOS) {
      await _connectionRepo.setup().mapLeft((l) {
        loggy.error('error setting up connection repository', l);
      }).run();
    }

    listenSelf((previous, next) async {
      if (previous == next) return;
      if (previous case AsyncData(:final value) when !value.isConnected) {
        if (next case AsyncData(value: final Connected _)) {
          await ref.read(hapticServiceProvider.notifier).heavyImpact();

          if (Platform.isAndroid && !ref.read(Preferences.storeReviewedByUser)) {
            if (await InAppReview.instance.isAvailable()) {
              await InAppReview.instance.requestReview();
              ref.read(Preferences.storeReviewedByUser.notifier).update(true);
            }
          }
        }
      }
    });

    ref.listen(authNotifierProvider, (_, next) => _refreshClientState(reason: 'auth changed'), fireImmediately: true);

    ref.listen(activeProfileProvider.select((value) => value.asData?.value), (previous, next) async {
      if (previous == null) return;
      final shouldReconnect = next == null || previous.id != next.id;
      if (shouldReconnect) {
        await reconnect(next);
      }
    });
    ref.watch(coreRestartSignalProvider);

    yield* _connectionRepo.watchConnectionStatus().doOnData(_handleCoreStatus);
  }

  ConnectionRepository get _connectionRepo => ref.read(connectionRepositoryProvider);

  Future<void> mayConnect() async {
    if (_computeClientState().phase == ClientConnectionPhase.disconnected) {
      await connectRequested();
    }
  }

  Future<void> toggleConnection() => connectRequested();

  Future<void> connectRequested() async {
    final computed = _computeClientState();
    _setClientState(computed, reason: 'connect requested');
    loggy.info('connect requested: state=${computed.phase.name}, selectedNodeName=${_selectedNodeNameSync()}');

    switch (computed.phase) {
      case ClientConnectionPhase.initializing:
        _showInfo('账号初始化中，请稍候');
      case ClientConnectionPhase.loggedOut:
        _showInfo('请先登录账号');
      case ClientConnectionPhase.disconnected || ClientConnectionPhase.failed:
        await ref.read(hapticServiceProvider.notifier).lightImpact();
        await _startUserConnection();
      case ClientConnectionPhase.connected:
        await ref.read(hapticServiceProvider.notifier).mediumImpact();
        await userDisconnect();
      case ClientConnectionPhase.preparing ||
          ClientConnectionPhase.requestingVpnPermission ||
          ClientConnectionPhase.connecting ||
          ClientConnectionPhase.reconnecting:
        loggy.debug('connect ignored while busy: state=${computed.phase.name}');
    }
  }

  Future<void> reconnect(ProfileEntity? profile) async {
    final current = _currentStatus;
    if (current == const Connected()) {
      if (profile == null) {
        loggy.info('no active profile, disconnecting');
        return userDisconnect();
      }
      loggy.info('active profile changed, reconnecting selectedNodeName=${_selectedNodeNameSync()}');
      await ref.read(Preferences.startedByUser.notifier).update(true);
      _setClientState(const ClientConnectionState.reconnecting(), reason: 'active profile changed');
      await _connectionRepo
          .reconnect(profile, ref.read(Preferences.disableMemoryLimit))
          .mapLeft(_handleConnectFailure)
          .run();
    }
  }

  Future<void> abortConnection() => userDisconnect();

  Future<void> userDisconnect() async {
    _manualDisconnecting = true;
    _userRequestedConnection = false;
    _vpnPermissionRequestedForAttempt = false;
    _autoReconnectRunning = false;
    _reconnectAttempts = 0;
    await ref.read(Preferences.startedByUser.notifier).update(false);
    loggy.info('user disconnect requested');
    await _disconnect();
  }

  final _singleStart = SingleCall();

  Future<void> _startUserConnection() async {
    await _singleStart.run(
      () async {
        _userRequestedConnection = true;
        _manualDisconnecting = false;
        _reconnectAttempts = 0;
        await ref.read(Preferences.startedByUser.notifier).update(true);
        await _connectThrottled();
      },
      onIgnored: () {
        loggy.debug('connect called while another connect/disconnect is still running, ignoring');
      },
    );
  }

  Future<void> _connectThrottled({bool reconnecting = false}) async {
    _setClientState(
      reconnecting ? const ClientConnectionState.reconnecting() : const ClientConnectionState.preparing(),
      reason: reconnecting ? 'reconnect preparing' : 'connect preparing',
    );

    var activeProfile = await ref.read(activeProfileProvider.future);
    if (activeProfile == null) {
      final synced = await _syncNodesForConnect();
      if (!synced) {
        await _fail(ConnectionErrorMapper.noNodes, reason: 'no nodes');
        return;
      }
      ref.invalidate(activeProfileProvider);
      activeProfile = await ref
          .read(activeProfileProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (activeProfile == null) {
        await _fail(ConnectionErrorMapper.noNodes, reason: 'no nodes after sync');
        return;
      }
    }

    if (Platform.isAndroid && !reconnecting) {
      _vpnPermissionRequestedForAttempt = true;
      _setClientState(const ClientConnectionState.requestingVpnPermission(), reason: 'vpn permission requested');
      loggy.info('vpn permission requested');
    } else {
      _setClientState(
        reconnecting ? const ClientConnectionState.reconnecting() : const ClientConnectionState.connecting(),
        reason: reconnecting ? 'reconnect start' : 'connect start',
      );
    }

    loggy.debug('starting core connection: reconnecting=$reconnecting, selectedNodeName=${_selectedNodeNameSync()}');
    await _connectionRepo
        .connect(activeProfile, ref.read(Preferences.disableMemoryLimit))
        .mapLeft((err) => _handleConnectFailure(err, reconnecting: reconnecting))
        .run();
  }

  Future<bool> _syncNodesForConnect() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState?.status != AuthStatus.loggedIn) return false;
    return ref.read(authNotifierProvider.notifier).syncNodes(showSuccessToast: false);
  }

  Future<void> _handleConnectFailure(ConnectionFailure err, {bool reconnecting = false}) async {
    loggy.warning('error connecting sanitized=${ConnectionErrorMapper.fromFailure(err)} rawType=${err.runtimeType}');
    if (err is MissingVpnPermission) {
      _vpnPermissionRequestedForAttempt = false;
      loggy.info('vpn permission denied, pendingConnect=false');
      await _fail(ConnectionErrorMapper.vpnPermissionRequired, reason: 'vpn permission denied');
      return;
    }

    final message = ConnectionErrorMapper.fromFailure(err);
    if (err.toString().contains('panic')) {
      await Sentry.captureException(Exception(err.toString()));
    }
    if (reconnecting && !_manualDisconnecting && _userRequestedConnection) {
      loggy.info('reconnect attempt failed sanitized=$message selectedNodeName=${_selectedNodeNameSync()}');
      _scheduleAutoReconnect();
      return;
    }
    await _fail(message, reason: 'connect failed');
  }

  Future<void> _disconnect() async {
    await _connectionRepo.disconnect().mapLeft((err) async {
      loggy.warning(
        'error disconnecting sanitized=${ConnectionErrorMapper.fromFailure(err)} rawType=${err.runtimeType}',
      );
      await _fail(ConnectionErrorMapper.fromFailure(err), reason: 'disconnect failed');
    }).run();
  }

  ConnectionStatus? get _currentStatus => state.valueOrNull ?? _lastCoreStatus;

  void _handleCoreStatus(ConnectionStatus event) {
    final previousStatus = _lastCoreStatus;
    final wasRunning = previousStatus is Connected || previousStatus is Connecting;
    _lastCoreStatus = event;

    if (event case Disconnected(connectionFailure: final _?) when PlatformUtils.isDesktop) {
      ref.read(Preferences.startedByUser.notifier).update(false);
    }

    if (event is Connected) {
      if (_vpnPermissionRequestedForAttempt) {
        loggy.info('vpn permission granted or already prepared, continuing connection');
      }
      _vpnPermissionRequestedForAttempt = false;
      _manualDisconnecting = false;
      _reconnectAttempts = 0;
      _setClientState(const ClientConnectionState.connected(), reason: 'core connected');
    } else if (event is Connecting) {
      _setClientState(const ClientConnectionState.connecting(), reason: 'core connecting');
    } else if (event is Disconnecting) {
      _setClientState(const ClientConnectionState.preparing(), reason: 'core disconnecting');
    } else if (event case Disconnected(connectionFailure: final failure?)) {
      final message = ConnectionErrorMapper.fromFailure(failure);
      if (failure is MissingVpnPermission) {
        _vpnPermissionRequestedForAttempt = false;
        loggy.info('vpn permission denied, pendingConnect=false');
        unawaited(_fail(ConnectionErrorMapper.vpnPermissionRequired, reason: 'vpn permission denied'));
      } else if (wasRunning && !_manualDisconnecting && _userRequestedConnection) {
        _scheduleAutoReconnect();
      } else {
        unawaited(_fail(message, reason: 'core disconnected with failure'));
      }
    } else if (event is Disconnected) {
      if (_manualDisconnecting || !_userRequestedConnection) {
        _manualDisconnecting = false;
        _setClientState(_computeClientState(), reason: 'manual/core disconnected');
      } else if (wasRunning) {
        _scheduleAutoReconnect();
      } else {
        _setClientState(_computeClientState(), reason: 'core disconnected');
      }
    }

    loggy.info('connection status: ${event.format()}');
  }

  void _scheduleAutoReconnect() {
    if (_autoReconnectRunning) return;
    if (_manualDisconnecting || !_userRequestedConnection) return;
    if (_reconnectAttempts >= _reconnectDelays.length) {
      unawaited(_fail(ConnectionErrorMapper.nodeUnstable, reason: 'auto reconnect exhausted'));
      return;
    }

    final attempt = _reconnectAttempts + 1;
    final delay = _reconnectDelays[_reconnectAttempts];
    _reconnectAttempts = attempt;
    _autoReconnectRunning = true;
    _setClientState(const ClientConnectionState.reconnecting(), reason: 'auto reconnect scheduled');
    loggy.info('reconnect attempt=$attempt delay=${delay.inSeconds}s selectedNodeName=${_selectedNodeNameSync()}');

    unawaited(
      Future<void>.delayed(delay, () async {
        _autoReconnectRunning = false;
        if (_manualDisconnecting || !_userRequestedConnection) return;
        if (_lastCoreStatus is Connected || _lastCoreStatus is Connecting) return;
        await _connectThrottled(reconnecting: true);
      }),
    );
  }

  Future<void> _fail(String message, {required String reason}) async {
    _vpnPermissionRequestedForAttempt = false;
    _autoReconnectRunning = false;
    _manualDisconnecting = false;
    _userRequestedConnection = false;
    _setClientState(ClientConnectionState.failed(message), reason: reason);
    _showError(message);
    await ref.read(Preferences.startedByUser.notifier).update(false);
  }

  ClientConnectionState _computeClientState() {
    final auth = ref.read(authNotifierProvider);
    if (auth.isLoading || auth.valueOrNull?.status == AuthStatus.initializing) {
      return const ClientConnectionState.initializing();
    }
    if (auth.valueOrNull?.status != AuthStatus.loggedIn) {
      return const ClientConnectionState.loggedOut();
    }

    return switch (_lastCoreStatus) {
      Connected() => const ClientConnectionState.connected(),
      Connecting() => const ClientConnectionState.connecting(),
      Disconnecting() => const ClientConnectionState.preparing(),
      Disconnected(connectionFailure: final failure?) => ClientConnectionState.failed(
        ConnectionErrorMapper.fromFailure(failure),
      ),
      Disconnected() => const ClientConnectionState.disconnected(),
    };
  }

  void _refreshClientState({required String reason}) {
    _setClientState(_computeClientState(), reason: reason);
  }

  void _setClientState(ClientConnectionState next, {required String reason}) {
    _logStateTransition(_clientState, next, reason: reason);
    _clientState = next;
    ref.read(clientConnectionStateProvider.notifier).state = next;
  }

  void _logStateTransition(ClientConnectionState previous, ClientConnectionState next, {required String reason}) {
    if (previous.phase == next.phase && previous.message == next.message) return;
    loggy.debug(
      'connection state transition: ${previous.phase.name} -> ${next.phase.name}, '
      'reason=$reason, selectedNodeName=${_selectedNodeNameSync()}',
    );
  }

  void _showError(String message) {
    ref.read(inAppNotificationControllerProvider).showErrorToast(message);
  }

  void _showInfo(String message) {
    ref.read(inAppNotificationControllerProvider).showInfoToast(message);
  }

  String _selectedNodeNameSync() {
    final selectedNode = ref.read(clientNodeSelectionProvider).valueOrNull?.selectedNode;
    return _safeNodeName(selectedNode?.name ?? '--');
  }

  String _safeNodeName(String value) {
    final sanitized = value.replaceAll(RegExp(r'https?://[^\s]+'), 'https://***');
    if (sanitized.length > 64) return '${sanitized.substring(0, 64)}…';
    return sanitized;
  }
}

@Riverpod(keepAlive: true)
Future<bool> serviceRunning(Ref ref) async {
  return await ref
      .watch(connectionNotifierProvider.selectAsync((data) => data.isConnected))
      .onError((error, stackTrace) => false);
}

class SingleCall {
  bool _running = false;

  Future<void> run(Future<void> Function() task, {required void Function() onIgnored}) async {
    if (_running) {
      onIgnored();
      return;
    }

    _running = true;
    try {
      return await task();
    } finally {
      _running = false;
    }
  }
}
