import 'dart:async';
import 'dart:io';

import 'package:hiddify/core/config/locked_core_config.dart';
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
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sentry/sentry.dart';

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
  bool _vpnPermissionStartFallbackScheduled = false;
  bool _autoReconnectRunning = false;
  bool _suppressActiveProfileReconnect = false;
  int _reconnectAttempts = 0;
  int _startAttemptId = 0;
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

    ref.listen(authNotifierProvider, (_, next) {
      _refreshClientState(reason: 'auth changed');
      final message = _subscriptionUnavailableMessage();
      if (message != null && (_lastCoreStatus is Connected || _clientState.phase == ClientConnectionPhase.connected)) {
        unawaited(_disconnectForSubscriptionUnavailable(message));
      }
    }, fireImmediately: true);

    ref.listen(activeProfileProvider.select((value) => value.asData?.value), (previous, next) async {
      if (previous == null) return;
      final shouldReconnect = next == null || previous.id != next.id;
      if (shouldReconnect) {
        if (_suppressActiveProfileReconnect) {
          DiagnosticEventBuffer.addSafe('active profile change ignored during node switch');
          loggy.info('active profile change ignored during node switch');
          return;
        }
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
    final computed = _actionableClientState();
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
          ClientConnectionPhase.reconnecting ||
          ClientConnectionPhase.stopping:
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
      final accessFailure = await _ensureSubscriptionAccessForConnect();
      if (accessFailure != null) {
        await _disconnectForSubscriptionUnavailable(accessFailure);
        return;
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

  Future<void> switchSelectedNode(String nodeId) async {
    final trimmedNodeId = nodeId.trim();
    if (trimmedNodeId.isEmpty) return;

    final previousSelection =
        ref.read(clientNodeSelectionProvider).valueOrNull ??
        await ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
    final alreadySelected = previousSelection.effectiveSelectedNodeId == trimmedNodeId;
    if (alreadySelected) return;

    final wasConnected = _lastCoreStatus is Connected || _clientState.phase == ClientConnectionPhase.connected;
    await ref.read(clientNodeSelectionProvider.notifier).selectNode(trimmedNodeId);
    DiagnosticEventBuffer.addSafe(
      'node switch selected cached node, connected=$wasConnected, selectedNodeName=${_selectedNodeNameSync()}',
    );
    if (!wasConnected) return;

    _startAttemptId++;
    _userRequestedConnection = true;
    _manualDisconnecting = false;
    _autoReconnectRunning = false;
    _reconnectAttempts = 0;
    await ref.read(Preferences.startedByUser.notifier).update(true);
    _setClientState(const ClientConnectionState.reconnecting(), reason: 'node switch requested');

    String? accessFailure;
    _suppressActiveProfileReconnect = true;
    try {
      accessFailure = await _ensureSubscriptionAccessForConnect();
    } finally {
      _suppressActiveProfileReconnect = false;
    }
    if (accessFailure != null) {
      await _disconnectForSubscriptionUnavailable(accessFailure);
      return;
    }
    DiagnosticEventBuffer.addSafe('node switch profile restore completed: subscriptionAccess=true');

    await ref.read(clientNodeSelectionProvider.notifier).selectNode(trimmedNodeId);
    final profile = await ref
        .read(activeProfileProvider.future)
        .timeout(const Duration(seconds: 3), onTimeout: () => null);
    if (profile == null) {
      await _fail(ConnectionErrorMapper.noNodes, reason: 'node switch no active profile');
      return;
    }

    loggy.info('node switch reconnecting selectedNodeName=${_selectedNodeNameSync()}');
    DiagnosticEventBuffer.addSafe('node switch reconnect requested selectedNodeName=${_selectedNodeNameSync()}');
    await _connectionRepo
        .reconnect(profile, ref.read(Preferences.disableMemoryLimit))
        .mapLeft((err) => _handleConnectFailure(err, reconnecting: true))
        .run();
  }

  Future<void> restartForConfigChange(ProfileEntity? profile) async {
    if (profile == null) return;
    if (_clientState.isBusy) {
      DiagnosticEventBuffer.addSafe(
        'config change observed while connection is busy; current start will use latest mode',
      );
      loggy.info('config change ignored while busy: state=${_clientState.phase.name}');
      return;
    }
    if (_currentStatus != const Connected()) {
      _refreshClientState(reason: 'config changed while stopped');
      return;
    }

    _startAttemptId++;
    _userRequestedConnection = true;
    _manualDisconnecting = true;
    _autoReconnectRunning = false;
    _reconnectAttempts = 0;
    _setClientState(const ClientConnectionState.reconnecting(), reason: 'config change restart');
    await ref.read(Preferences.startedByUser.notifier).update(true);

    final stopResult = await _connectionRepo.disconnect().run();
    stopResult.mapLeft((err) {
      loggy.warning('config change stop before restart failed: ${ConnectionErrorMapper.fromFailure(err)}');
      return err;
    });

    _manualDisconnecting = false;
    _userRequestedConnection = true;
    _lastCoreStatus = const ConnectionStatus.disconnected();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _connectThrottled(reconnecting: true, attemptId: ++_startAttemptId);
  }

  Future<void> abortConnection() => userDisconnect();

  Future<void> userDisconnect() async {
    final current = _actionableClientState();
    if (current.phase == ClientConnectionPhase.disconnected || current.phase == ClientConnectionPhase.loggedOut) {
      loggy.debug('disconnect ignored because state=${current.phase.name}');
      _resetUserConnectionIntent();
      _setClientState(current, reason: 'disconnect ignored while stopped');
      return;
    }
    if (current.phase == ClientConnectionPhase.stopping) {
      loggy.debug('disconnect ignored because stop is already in progress');
      return;
    }

    _manualDisconnecting = true;
    _resetUserConnectionIntent();
    _startAttemptId++;
    _setClientState(const ClientConnectionState.stopping(), reason: 'user disconnect requested');
    await ref.read(Preferences.startedByUser.notifier).update(false);
    loggy.info('user disconnect requested');
    await _disconnect();
  }

  final _singleStart = SingleCall();

  Future<void> _startUserConnection() async {
    if (_clientState.phase == ClientConnectionPhase.preparing ||
        _clientState.phase == ClientConnectionPhase.requestingVpnPermission ||
        _clientState.phase == ClientConnectionPhase.connecting ||
        _clientState.phase == ClientConnectionPhase.connected ||
        _clientState.phase == ClientConnectionPhase.reconnecting ||
        _clientState.phase == ClientConnectionPhase.stopping) {
      loggy.debug('start ignored because current state=${_clientState.phase.name}');
      return;
    }

    await _singleStart.run(
      () async {
        _userRequestedConnection = true;
        _manualDisconnecting = false;
        _reconnectAttempts = 0;
        final attemptId = ++_startAttemptId;
        await ref.read(Preferences.startedByUser.notifier).update(true);
        await _connectThrottled(attemptId: attemptId);
      },
      onIgnored: () {
        loggy.debug('connect called while another connect/disconnect is still running, ignoring');
      },
    );
  }

  Future<void> _connectThrottled({bool reconnecting = false, int? attemptId}) async {
    final currentAttemptId = attemptId ?? ++_startAttemptId;
    _setClientState(
      reconnecting ? const ClientConnectionState.reconnecting() : const ClientConnectionState.preparing(),
      reason: reconnecting ? 'reconnect preparing' : 'connect preparing',
    );

    final accessFailure = await _ensureSubscriptionAccessForConnect();
    if (accessFailure != null) {
      await _fail(accessFailure, reason: 'subscription access check failed');
      return;
    }

    final unavailableMessage = _subscriptionUnavailableMessage();
    if (unavailableMessage != null) {
      await _fail(unavailableMessage, reason: 'subscription unavailable');
      return;
    }

    var activeProfile = await ref.read(activeProfileProvider.future);
    if (!_isStartAttemptActive(currentAttemptId)) {
      loggy.debug('connect aborted before node preparation completed');
      return;
    }
    final cachedNodes = await _readCachedNodeSelection();
    if (activeProfile != null && cachedNodes.selectedNode == null) {
      loggy.info('node cache empty before connect, syncing nodes in background');
      unawaited(_syncNodesForConnect());
    }
    if (activeProfile == null) {
      if (cachedNodes.selectedNode != null) {
        loggy.info('cached nodes found but active profile is missing; preparing profile before connect');
        DiagnosticEventBuffer.addSafe('cached nodes available; active profile missing, preparing profile');
      }
      final synced = await _syncNodesForConnect();
      if (!synced) {
        if (_isStartAttemptActive(currentAttemptId)) await _fail(ConnectionErrorMapper.noNodes, reason: 'no nodes');
        return;
      }
      if (!_isStartAttemptActive(currentAttemptId)) {
        loggy.debug('connect aborted after node sync');
        return;
      }
      ref.invalidate(activeProfileProvider);
      activeProfile = await ref
          .read(activeProfileProvider.future)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      if (activeProfile == null) {
        if (_isStartAttemptActive(currentAttemptId)) {
          await _fail(ConnectionErrorMapper.noNodes, reason: 'no nodes after sync');
        }
        return;
      }
    }
    if (!_isStartAttemptActive(currentAttemptId)) {
      loggy.debug('connect aborted before core start');
      return;
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
    if (!_isStartAttemptActive(currentAttemptId) && _lastCoreStatus is Connected) {
      loggy.info('core connected after user cancelled start; stopping immediately');
      unawaited(_disconnect());
    }
  }

  Future<bool> _syncNodesForConnect() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState?.status != AuthStatus.loggedIn) return false;
    return ref.read(authNotifierProvider.notifier).syncNodes(showSuccessToast: false);
  }

  Future<String?> _ensureSubscriptionAccessForConnect() async {
    final authState = ref.read(authNotifierProvider).valueOrNull;
    if (authState?.status != AuthStatus.loggedIn) return '请先登录账号';
    final message = await ref.read(authNotifierProvider.notifier).ensureSubscriptionAccessForConnect();
    if (message != null) {
      DiagnosticEventBuffer.addSafe('subscription access blocked connection: $message');
    }
    return message;
  }

  Future<ClientNodeSelection> _readCachedNodeSelection() async {
    try {
      return await ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
    } catch (error, stackTrace) {
      loggy.debug('failed to read cached nodes before connect', error, stackTrace);
      return const ClientNodeSelection.empty();
    }
  }

  Future<void> _handleConnectFailure(ConnectionFailure err, {bool reconnecting = false}) async {
    loggy.warning('error connecting sanitized=${ConnectionErrorMapper.fromFailure(err)} rawType=${err.runtimeType}');
    if (!_userRequestedConnection || _manualDisconnecting || _clientState.phase == ClientConnectionPhase.stopping) {
      loggy.info('connect failure suppressed because connection was cancelled or stopping');
      DiagnosticEventBuffer.addSafe('connect failure suppressed after user stop/cancel');
      await _cleanupPartialStart();
      if (_manualDisconnecting || _clientState.phase == ClientConnectionPhase.stopping) {
        _setClientState(const ClientConnectionState.disconnected(), reason: 'cancelled start failure suppressed');
      }
      return;
    }
    if (err is MissingVpnPermission) {
      _vpnPermissionRequestedForAttempt = false;
      loggy.info('vpn permission denied, pendingConnect=false');
      DiagnosticEventBuffer.addSafe('vpn permission denied, pendingConnect=false');
      await _fail(ConnectionErrorMapper.vpnPermissionRequired, reason: 'vpn permission denied');
      return;
    }

    final message = ConnectionErrorMapper.fromFailure(err);
    if (_isVpnPermissionStartRace(message, reconnecting: reconnecting)) {
      loggy.info(
        'connect start still waiting for VPN permission/service callback; suppressing transient start failure',
      );
      DiagnosticEventBuffer.addSafe('vpn permission/service start pending; transient start failure suppressed');
      _setClientState(const ClientConnectionState.requestingVpnPermission(), reason: 'vpn permission still pending');
      _scheduleVpnPermissionStartFallback();
      return;
    }
    if (err.toString().contains('panic')) {
      await Sentry.captureException(Exception(err.toString()));
    }
    if (reconnecting && !_manualDisconnecting && _userRequestedConnection) {
      loggy.info('reconnect attempt failed sanitized=$message selectedNodeName=${_selectedNodeNameSync()}');
      _scheduleAutoReconnect();
      return;
    }
    await _cleanupPartialStart();
    await _fail(message, reason: 'connect failed');
  }

  Future<void> _disconnect() async {
    if (_lastCoreStatus is Disconnected &&
        _clientState.phase != ClientConnectionPhase.preparing &&
        _clientState.phase != ClientConnectionPhase.connecting &&
        _clientState.phase != ClientConnectionPhase.requestingVpnPermission &&
        _clientState.phase != ClientConnectionPhase.reconnecting) {
      _manualDisconnecting = false;
      _lastCoreStatus = const ConnectionStatus.disconnected();
      _setClientState(const ClientConnectionState.disconnected(), reason: 'disconnect ignored while core stopped');
      await ref.read(Preferences.startedByUser.notifier).update(false);
      return;
    }

    _setClientState(const ClientConnectionState.stopping(), reason: 'core stopping');
    final result = await _connectionRepo.disconnect().run();
    await result.match(
      (err) async {
        final message = ConnectionErrorMapper.fromFailure(err);
        loggy.warning('error disconnecting sanitized=$message rawType=${err.runtimeType}');
        if (_manualDisconnecting) {
          DiagnosticEventBuffer.addSafe('disconnect completed with benign local error suppressed');
          _manualDisconnecting = false;
          _userRequestedConnection = false;
          _vpnPermissionRequestedForAttempt = false;
          _vpnPermissionStartFallbackScheduled = false;
          _autoReconnectRunning = false;
          _reconnectAttempts = 0;
          _lastCoreStatus = const ConnectionStatus.disconnected();
          _setClientState(const ClientConnectionState.disconnected(), reason: 'manual disconnect completed');
          await ref.read(Preferences.startedByUser.notifier).update(false);
          return;
        }
        await _fail(message, reason: 'disconnect failed');
      },
      (_) async {
        if (_manualDisconnecting) {
          _manualDisconnecting = false;
          _lastCoreStatus = const ConnectionStatus.disconnected();
          _setClientState(const ClientConnectionState.disconnected(), reason: 'manual disconnect completed');
          await ref.read(Preferences.startedByUser.notifier).update(false);
        }
      },
    );
  }

  Future<void> _disconnectForSubscriptionUnavailable(String message) async {
    if (_clientState.phase == ClientConnectionPhase.stopping) return;
    _manualDisconnecting = true;
    _resetUserConnectionIntent();
    _startAttemptId++;
    _setClientState(const ClientConnectionState.stopping(), reason: 'subscription unavailable while connected');
    await ref.read(Preferences.startedByUser.notifier).update(false);

    final result = await _connectionRepo.disconnect().run();
    result.mapLeft((err) {
      loggy.debug(
        'disconnect for subscription unavailable completed with local error: ${ConnectionErrorMapper.fromFailure(err)}',
      );
      return err;
    });
    _manualDisconnecting = false;
    _lastCoreStatus = const ConnectionStatus.disconnected();
    _setClientState(ClientConnectionState.failed(message), reason: 'subscription unavailable');
    _showError(message);
  }

  ConnectionStatus? get _currentStatus => state.valueOrNull ?? _lastCoreStatus;

  void _handleCoreStatus(ConnectionStatus event) {
    final previousStatus = _lastCoreStatus;
    final wasRunning = previousStatus is Connected || previousStatus is Connecting;
    final wasDisconnecting = previousStatus is Disconnecting;
    _lastCoreStatus = event;
    DiagnosticEventBuffer.add('core status=${event.format()}');

    if (event case Disconnected(connectionFailure: final _?) when PlatformUtils.isDesktop) {
      ref.read(Preferences.startedByUser.notifier).update(false);
    }

    if (event is Connected) {
      if (!_userRequestedConnection && (_manualDisconnecting || _clientState.phase == ClientConnectionPhase.stopping)) {
        loggy.info('core connected while stop was requested; stopping immediately');
        unawaited(_disconnect());
        return;
      }
      if (_vpnPermissionRequestedForAttempt) {
        loggy.info('vpn permission granted or already prepared, continuing connection');
      }
      _vpnPermissionRequestedForAttempt = false;
      _vpnPermissionStartFallbackScheduled = false;
      _manualDisconnecting = false;
      _reconnectAttempts = 0;
      _setClientState(const ClientConnectionState.connected(), reason: 'core connected');
      _enforceSelectedProxyOutbound();
      if (previousStatus is! Connected) _showSuccess('蝴蝶加速 已连接');
    } else if (event is Connecting) {
      if (_manualDisconnecting || _clientState.phase == ClientConnectionPhase.stopping) {
        loggy.info('core reported connecting while stop is pending; preserving stopping state');
        _setClientState(const ClientConnectionState.stopping(), reason: 'core connecting while stopping');
        return;
      }
      _vpnPermissionRequestedForAttempt = false;
      _vpnPermissionStartFallbackScheduled = false;
      _setClientState(const ClientConnectionState.connecting(), reason: 'core connecting');
    } else if (event is Disconnecting) {
      if (ClientConnectionStatePolicy.shouldPreserveReconnectDuringCoreRestart(
        userRequestedConnection: _userRequestedConnection,
        manualDisconnecting: _manualDisconnecting,
        current: _clientState,
      )) {
        DiagnosticEventBuffer.addSafe('connection state preserved reconnecting during core disconnecting event');
      } else {
        _setClientState(const ClientConnectionState.stopping(), reason: 'core disconnecting');
      }
    } else if (event case Disconnected(connectionFailure: final failure?)) {
      final message = ConnectionErrorMapper.fromFailure(failure);
      if (ClientConnectionStatePolicy.shouldSuppressDisconnectFailure(
        manualDisconnecting: _manualDisconnecting || _clientState.phase == ClientConnectionPhase.stopping,
        wasDisconnecting: wasDisconnecting,
      )) {
        _manualDisconnecting = false;
        _userRequestedConnection = false;
        _vpnPermissionRequestedForAttempt = false;
        _vpnPermissionStartFallbackScheduled = false;
        _autoReconnectRunning = false;
        _reconnectAttempts = 0;
        DiagnosticEventBuffer.addSafe('manual/core disconnect failure suppressed');
        _setClientState(const ClientConnectionState.disconnected(), reason: 'manual/core disconnected');
        _showInfo('蝴蝶加速 已断开');
      } else if (failure is MissingVpnPermission) {
        _vpnPermissionRequestedForAttempt = false;
        _vpnPermissionStartFallbackScheduled = false;
        loggy.info('vpn permission denied, pendingConnect=false');
        DiagnosticEventBuffer.addSafe('vpn permission denied, pendingConnect=false');
        unawaited(_fail(ConnectionErrorMapper.vpnPermissionRequired, reason: 'vpn permission denied'));
      } else if (_isVpnPermissionStartRace(message, reconnecting: false)) {
        loggy.info('core emitted transient start failure while VPN permission flow is pending; suppressing toast');
        DiagnosticEventBuffer.addSafe('vpn permission/service status pending; transient start failure suppressed');
        _setClientState(const ClientConnectionState.requestingVpnPermission(), reason: 'vpn permission still pending');
        _scheduleVpnPermissionStartFallback();
      } else if (wasRunning && !_manualDisconnecting && _userRequestedConnection) {
        _scheduleAutoReconnect();
      } else {
        unawaited(_fail(message, reason: 'core disconnected with failure'));
      }
    } else if (event is Disconnected) {
      if (_manualDisconnecting || !_userRequestedConnection) {
        _manualDisconnecting = false;
        _setClientState(_computeClientState(), reason: 'manual/core disconnected');
        if (previousStatus is Connected || previousStatus is Disconnecting) _showInfo('蝴蝶加速 已断开');
      } else if (wasRunning) {
        _scheduleAutoReconnect();
      } else if (ClientConnectionStatePolicy.shouldPreserveReconnectDuringCoreRestart(
        userRequestedConnection: _userRequestedConnection,
        manualDisconnecting: _manualDisconnecting,
        current: _clientState,
      )) {
        DiagnosticEventBuffer.addSafe('connection state preserved reconnecting during core disconnected event');
      } else {
        _setClientState(_computeClientState(), reason: 'core disconnected');
      }
    }

    loggy.info('connection status: ${event.format()}');
  }

  void _scheduleAutoReconnect() {
    if (_autoReconnectRunning) return;
    if (_manualDisconnecting || !_userRequestedConnection) return;
    final unavailableMessage = _subscriptionUnavailableMessage();
    if (unavailableMessage != null) {
      unawaited(_fail(unavailableMessage, reason: 'auto reconnect blocked by subscription unavailable'));
      return;
    }
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
        await _connectThrottled(reconnecting: true, attemptId: ++_startAttemptId);
      }),
    );
  }

  Future<void> _fail(String message, {required String reason}) async {
    _vpnPermissionRequestedForAttempt = false;
    _vpnPermissionStartFallbackScheduled = false;
    _autoReconnectRunning = false;
    _manualDisconnecting = false;
    _userRequestedConnection = false;
    _lastCoreStatus = const ConnectionStatus.disconnected();
    _setClientState(ClientConnectionState.failed(message), reason: reason);
    _showError(message);
    await ref.read(Preferences.startedByUser.notifier).update(false);
  }

  Future<void> shutdownForExit({bool keepConnection = false}) async {
    if (keepConnection) {
      loggy.info('app exit requested, preserving running connection by setting');
      return;
    }
    loggy.info('app exit requested, stopping core and restoring system state');
    await userDisconnect().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        loggy.warning('timeout while stopping core during app exit');
      },
    );
  }

  ClientConnectionState _computeClientState() {
    final auth = ref.read(authNotifierProvider);
    final authValue = auth.valueOrNull;
    if ((auth.isLoading && authValue == null) || authValue?.status == AuthStatus.initializing) {
      return const ClientConnectionState.initializing();
    }
    if (authValue?.status != AuthStatus.loggedIn) {
      return const ClientConnectionState.loggedOut();
    }
    final unavailableMessage = _subscriptionUnavailableMessage();
    if (unavailableMessage != null) {
      return ClientConnectionState.failed(unavailableMessage);
    }

    return switch (_lastCoreStatus) {
      Connected() => const ClientConnectionState.connected(),
      Connecting() => const ClientConnectionState.connecting(),
      Disconnecting() => const ClientConnectionState.stopping(),
      Disconnected(connectionFailure: final failure?) => ClientConnectionState.failed(
        ConnectionErrorMapper.fromFailure(failure),
      ),
      Disconnected() => const ClientConnectionState.disconnected(),
    };
  }

  void _refreshClientState({required String reason}) {
    final computed = _computeClientState();
    if (_shouldPreserveActiveConnectionState(computed)) {
      DiagnosticEventBuffer.addSafe(
        'connection state refresh preserved ${_clientState.phase.name}, reason=$reason, computed=${computed.phase.name}',
      );
      return;
    }
    _setClientState(computed, reason: reason);
  }

  ClientConnectionState _actionableClientState() {
    if (_clientState.phase == ClientConnectionPhase.preparing ||
        _clientState.phase == ClientConnectionPhase.requestingVpnPermission ||
        _clientState.phase == ClientConnectionPhase.connecting ||
        _clientState.phase == ClientConnectionPhase.reconnecting ||
        _clientState.phase == ClientConnectionPhase.stopping) {
      return _clientState;
    }
    if (_clientState.phase == ClientConnectionPhase.connected && _lastCoreStatus is Connected) {
      return _clientState;
    }
    return _computeClientState();
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
    DiagnosticEventBuffer.addSafe(
      'connection state ${previous.phase.name}->${next.phase.name}, reason=$reason, selectedNodeName=${_selectedNodeNameSync()}',
    );
  }

  bool _isVpnPermissionStartRace(String message, {required bool reconnecting}) {
    if (reconnecting) return false;
    if (!_vpnPermissionRequestedForAttempt) return false;
    if (_clientState.phase != ClientConnectionPhase.requestingVpnPermission &&
        _clientState.phase != ClientConnectionPhase.connecting &&
        _clientState.phase != ClientConnectionPhase.preparing) {
      return false;
    }
    return message == ConnectionErrorMapper.coreStartFailed;
  }

  bool _shouldPreserveActiveConnectionState(ClientConnectionState computed) {
    return ClientConnectionStatePolicy.shouldPreserveActiveState(
      userRequestedConnection: _userRequestedConnection,
      current: _clientState,
      computed: computed,
    );
  }

  void _scheduleVpnPermissionStartFallback() {
    if (_vpnPermissionStartFallbackScheduled) return;
    _vpnPermissionStartFallbackScheduled = true;
    unawaited(
      Future<void>.delayed(const Duration(seconds: 45), () async {
        _vpnPermissionStartFallbackScheduled = false;
        if (!_vpnPermissionRequestedForAttempt) return;
        if (_lastCoreStatus is Connected || _lastCoreStatus is Connecting) return;
        if (_clientState.phase != ClientConnectionPhase.requestingVpnPermission) return;
        _vpnPermissionRequestedForAttempt = false;
        DiagnosticEventBuffer.addSafe('vpn permission/service start timeout');
        await _fail(ConnectionErrorMapper.vpnPermissionRequired, reason: 'vpn permission start timeout');
      }),
    );
  }

  void _enforceSelectedProxyOutbound() {
    final selected = ref.read(clientNodeSelectionProvider).valueOrNull?.selectedNode?.id.trim();
    if (selected == null || selected.isEmpty) return;

    unawaited(
      ref.read(proxyRepositoryProvider).selectProxy(LockedCoreConfig.outboundTag, selected).mapLeft((err) {
        loggy.debug('selected outbound enforcement skipped: $err');
        return err;
      }).run(),
    );
  }

  void _showError(String message) {
    ref.read(inAppNotificationControllerProvider).showErrorToast(message);
  }

  void _showInfo(String message) {
    ref.read(inAppNotificationControllerProvider).showInfoToast(message);
  }

  void _showSuccess(String message) {
    ref.read(inAppNotificationControllerProvider).showSuccessToast(message);
  }

  String? _subscriptionUnavailableMessage() {
    final subscription = ref.read(authNotifierProvider).valueOrNull?.session?.subscription;
    if (subscription == null) return null;
    if (!subscription.canConnect) {
      if (subscription.isNormalUser) return '请先开通会员';
      if (subscription.isSubscriptionExpired) return '请开通会员';
      if (subscription.isTrafficUnavailable) return '套餐流量已用尽，请续费后再连接';
      if (subscription.isBanned) return '账号不可用，请联系客服';
      return '请先开通会员';
    }
    if (subscription.isSubscriptionExpired) return '请开通会员';
    if (subscription.isTrafficUnavailable) return '套餐流量已用尽，请续费后再连接';
    return null;
  }

  bool _isStartAttemptActive(int attemptId) {
    return _userRequestedConnection && !_manualDisconnecting && attemptId == _startAttemptId;
  }

  void _resetUserConnectionIntent() {
    _userRequestedConnection = false;
    _vpnPermissionRequestedForAttempt = false;
    _vpnPermissionStartFallbackScheduled = false;
    _autoReconnectRunning = false;
    _reconnectAttempts = 0;
  }

  Future<void> _cleanupPartialStart() async {
    if (_lastCoreStatus is Disconnected) return;
    try {
      await _connectionRepo.disconnect().run();
    } catch (error, stackTrace) {
      loggy.debug('partial start cleanup skipped', error, stackTrace);
    } finally {
      _lastCoreStatus = const ConnectionStatus.disconnected();
    }
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
