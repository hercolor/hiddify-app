import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/diagnostics/diagnostic_event_buffer.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/data/profile_repository.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/data/client_node_store.dart';
import 'package:hiddify/features/proxy/model/client_node.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier with AppLogger {
  @override
  Future<AuthState> build() async {
    final bootstrapWatch = Stopwatch()..start();
    const initialState = AuthState.initializing();
    unawaited(_logAuthDebug(initialState, userInfoLoaded: false));
    try {
      final session = await ref.read(authTokenStorageProvider).read();
      if (session == null || session.authData.trim().isEmpty) {
        const nextState = AuthState.loggedOut();
        await _logAuthDebug(nextState, userInfoLoaded: false);
        loggy.debug('xboard bootstrapAuthMs=${bootstrapWatch.elapsedMilliseconds}');
        return nextState;
      }

      final nextState = AuthState.loggedIn(session);
      await _logAuthDebug(nextState, userInfoLoaded: session.subscription != null);
      unawaited(_syncNodesInBackground(session));
      loggy.debug('xboard bootstrapAuthMs=${bootstrapWatch.elapsedMilliseconds}');
      return nextState;
    } catch (error, stackTrace) {
      loggy.warning('xboard auth bootstrap failed', error, stackTrace);
      const nextState = AuthState.loggedOut();
      await _logAuthDebug(nextState, userInfoLoaded: false);
      loggy.debug('xboard bootstrapAuthMs=${bootstrapWatch.elapsedMilliseconds}');
      return nextState;
    } finally {
      bootstrapWatch.stop();
    }
  }

  Future<void> login(String email, String password) async {
    if (state.isLoading) return;
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final loginService = await ref.read(loginServiceProvider.future);
      final session = await loginService
          .login(email: email, password: password)
          .match((err) => throw err, (session) => session)
          .run();

      await ref.read(authTokenStorageProvider).save(session);
      var syncedSession = session;
      var userInfoSynced = false;
      try {
        final result = await _fetchSubscriptionAndImport(session);
        syncedSession = result.session;
        userInfoSynced = true;
      } catch (error, stackTrace) {
        loggy.warning('failed to sync xboard user info after login', error, stackTrace);
        DiagnosticEventBuffer.add('xboard user info sync after login failed: ${_safeError(error)}');
        ref.read(inAppNotificationControllerProvider).showErrorToast('登录成功，用户信息同步失败，请稍后重试');
      }
      await ref.read(authTokenStorageProvider).save(syncedSession);
      ref.read(inAppNotificationControllerProvider).showSuccessToast(userInfoSynced ? '登录成功' : '已登录');
      final nextState = AuthState.loggedIn(syncedSession);
      await _logAuthDebug(nextState, userInfoLoaded: syncedSession.subscription != null);
      return nextState;
    });
  }

  Future<void> refreshSubscription() async {
    await syncNodes();
  }

  Future<bool> syncNodes({bool showSuccessToast = true}) async {
    final current = state.valueOrNull?.session;
    if (current == null) {
      ref.read(inAppNotificationControllerProvider).showErrorToast('请先登录账号');
      return false;
    }

    try {
      final result = await _fetchSubscriptionAndImport(current, showNodeFailureToast: showSuccessToast);
      final session = result.session;
      await ref.read(authTokenStorageProvider).save(session);
      final nextState = AuthState.loggedIn(session);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: true);
      if (showSuccessToast) {
        if (result.nodesSynced) {
          ref.read(inAppNotificationControllerProvider).showSuccessToast('节点已同步');
        }
      }
      return result.nodesSynced;
    } catch (error, stackTrace) {
      loggy.warning('failed to sync xboard nodes', error, stackTrace);
      DiagnosticEventBuffer.add('xboard syncNodes failed: ${_safeError(error)}');
      final nextState = AuthState.loggedIn(current);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: current.subscription != null);
      ref.read(inAppNotificationControllerProvider).showErrorToast('节点同步失败，正在使用本地缓存');
      return false;
    }
  }

  Future<void> importSubscriptionToProfiles() async {
    await syncNodes();
  }

  Future<void> logout() async {
    await ref.read(authTokenStorageProvider).clear();
    state = const AsyncData(AuthState.loggedOut());
    await _logAuthDebug(const AuthState.loggedOut(), userInfoLoaded: false);
    ref.read(inAppNotificationControllerProvider).showSuccessToast('已退出登录');
  }

  Future<({AuthSession session, bool nodesSynced})> _fetchSubscriptionAndImport(
    AuthSession session, {
    bool showNodeFailureToast = true,
  }) async {
    final subscriptionService = await ref.read(userSubscriptionServiceProvider.future);
    final syncUserWatch = Stopwatch()..start();
    final subscription = await subscriptionService
        .fetchSubscription(session.authData, subscribeToken: session.subscribeToken)
        .match((err) => throw err, (subscription) => subscription)
        .run();
    syncUserWatch.stop();
    final subscriptionUrl = subscription.subscribeUrl.trim();
    final syncedSession = session.copyWith(subscription: subscription);
    await ref.read(authTokenStorageProvider).save(syncedSession);
    loggy.info(
      'xboard subscription ready: '
      'urlExists=${subscriptionUrl.isNotEmpty}, '
      'urlLength=${subscriptionUrl.length}, '
      'planExists=${subscription.planName?.trim().isNotEmpty == true}, '
      'hasTraffic=${subscription.hasTrafficInfo}',
    );
    DiagnosticEventBuffer.add(
      'xboard subscription ready: urlExists=${subscriptionUrl.isNotEmpty}, '
      'urlLength=${subscriptionUrl.length}, planExists=${subscription.planName?.trim().isNotEmpty == true}, '
      'hasTraffic=${subscription.hasTrafficInfo}',
    );

    final syncNodesWatch = Stopwatch()..start();
    var nodesSynced = false;
    var nodeSummary = _nodeDebugFallback();
    try {
      if (subscriptionUrl.isEmpty) {
        throw const AuthFailure.badResponse('未获取到节点信息');
      }
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.upsertRemote(subscriptionUrl).match((err) => throw err, (_) => unit).run();
      loggy.debug('xboard remote profile import succeeded');
      DiagnosticEventBuffer.add('xboard remote profile import succeeded');
      ref.invalidate(activeProfileProvider);
      nodeSummary = await _cacheNodesFromActiveProfile(repo);
      nodesSynced = true;
      if (nodeSummary.nodeCount == 0) {
        loggy.info('xboard node cache is empty after import; core will refresh visible nodes on connect');
        DiagnosticEventBuffer.add('xboard node cache empty after import; visible nodes will refresh when core starts');
      }
    } catch (error, stackTrace) {
      loggy.warning(
        'failed to import xboard nodes, preserving user subscription: ${_safeError(error)}',
        null,
        stackTrace,
      );
      DiagnosticEventBuffer.add('xboard remote profile import failed: ${_safeError(error)}');
      if (showNodeFailureToast) {
        ref.read(inAppNotificationControllerProvider).showErrorToast('节点同步失败，正在使用本地缓存');
      }
    }
    syncNodesWatch.stop();
    loggy.info(
      'xboard sync completed, '
      'urlLength=${subscriptionUrl.length}, '
      'nodeCount=${nodeSummary.nodeCount}, '
      'selectedNodeId=${nodeSummary.selectedNodeId}, '
      'selectedNodeName=${nodeSummary.selectedNodeName}, '
      'nodesSynced=$nodesSynced, '
      'syncUserMs=${syncUserWatch.elapsedMilliseconds}, '
      'syncNodesMs=${syncNodesWatch.elapsedMilliseconds}',
    );
    DiagnosticEventBuffer.add(
      'xboard sync completed: nodeCount=${nodeSummary.nodeCount}, '
      'selectedNodeName=${nodeSummary.selectedNodeName}, profileImported=$nodesSynced, '
      'syncUserMs=${syncUserWatch.elapsedMilliseconds}, syncNodesMs=${syncNodesWatch.elapsedMilliseconds}',
    );
    return (session: syncedSession, nodesSynced: nodesSynced);
  }

  Future<void> _syncNodesInBackground(AuthSession session) async {
    try {
      final result = await _fetchSubscriptionAndImport(session, showNodeFailureToast: false);
      final syncedSession = result.session;
      if (!_isCurrentSession(session)) return;
      await ref.read(authTokenStorageProvider).save(syncedSession);
      final nextState = AuthState.loggedIn(syncedSession);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: true);
    } catch (error, stackTrace) {
      loggy.warning('failed to sync xboard nodes during bootstrap', error, stackTrace);
      if (!_isCurrentSession(session)) return;
      final nextState = AuthState.loggedIn(state.valueOrNull?.session ?? session);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: nextState.session?.subscription != null);
      ref.read(inAppNotificationControllerProvider).showErrorToast('节点同步失败，正在使用本地缓存');
    }
  }

  bool _isCurrentSession(AuthSession session) {
    final current = state.valueOrNull?.session;
    return state.valueOrNull?.isLoggedIn == true && current?.authData == session.authData;
  }

  Future<void> _logAuthDebug(AuthState authState, {required bool userInfoLoaded}) async {
    final nodeSummary = await _readNodeDebugSummary();
    final authData = authState.session?.authData.trim();
    loggy.debug(
      'xboard auth debug: '
      'authState=${authState.status.name}, '
      'hasAuthData=${authData?.isNotEmpty == true}, '
      'profileName=${nodeSummary.profileName}, '
      'nodeCount=${nodeSummary.nodeCount}, '
      'selectedNodeId=${nodeSummary.selectedNodeId}, '
      'selectedNodeName=${nodeSummary.selectedNodeName}, '
      'userInfoLoaded=$userInfoLoaded, '
      'customerServiceConfigured=${authState.session?.subscription?.customerService?.trim().isNotEmpty == true}',
    );
  }

  Future<({String profileName, int nodeCount, String selectedNodeId, String selectedNodeName})>
  _cacheNodesFromActiveProfile(ProfileRepository repo) async {
    try {
      final profilesEither = await repo.watchAll().first.timeout(const Duration(seconds: 2));
      final profiles = profilesEither.getOrElse((_) => const <ProfileEntity>[]);
      final profile = profiles.where((profile) => profile.active).firstOrNull ?? profiles.firstOrNull;
      if (profile == null) return _nodeDebugFallback();

      final rawConfig = await repo.getRawConfig(profile.id).match((err) => '', (content) => content).run();
      var nodes = ClientNodeParser.parse(rawConfig);
      var source = 'rawProfile';
      if (nodes.isEmpty) {
        final generatedConfig = await repo.generateConfig(profile.id).match((err) => '', (content) => content).run();
        nodes = ClientNodeParser.parse(generatedConfig);
        source = 'generatedConfig';
      }
      if (nodes.isNotEmpty) {
        await ref.read(clientNodeSelectionProvider.notifier).cacheNodes(nodes, profileName: profile.name);
      }
      final selection =
          ref.read(clientNodeSelectionProvider).valueOrNull ??
          await ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
      final summary = _nodeDebugFromSelection(selection.copyWith(profileName: profile.name));
      DiagnosticEventBuffer.add(
        'xboard node cache parsed: source=$source, profileName=${summary.profileName}, '
        'nodeCount=${summary.nodeCount}, selectedNodeName=${summary.selectedNodeName}',
      );
      return summary;
    } catch (error, stackTrace) {
      loggy.debug('failed to cache sanitized node summary', error, stackTrace);
      DiagnosticEventBuffer.add('xboard node cache failed: ${_safeError(error)}');
      return _nodeDebugFallback();
    }
  }

  Future<({String profileName, int nodeCount, String selectedNodeId, String selectedNodeName})>
  _readNodeDebugSummary() async {
    try {
      final selection =
          ref.read(clientNodeSelectionProvider).valueOrNull ??
          await ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
      return _nodeDebugFromSelection(selection);
    } catch (error, stackTrace) {
      loggy.debug('failed to read sanitized node debug summary', error, stackTrace);
      return _nodeDebugFallback();
    }
  }

  ({String profileName, int nodeCount, String selectedNodeId, String selectedNodeName}) _nodeDebugFromSelection(
    ClientNodeSelection selection,
  ) {
    final selectedNode = selection.selectedNode;
    return (
      profileName: _safeLogValue(selection.profileName),
      nodeCount: selection.nodeCount,
      selectedNodeId: _safeLogValue(selection.effectiveSelectedNodeId),
      selectedNodeName: _safeLogValue(selectedNode?.name),
    );
  }

  ({String profileName, int nodeCount, String selectedNodeId, String selectedNodeName}) _nodeDebugFallback() =>
      (profileName: '--', nodeCount: 0, selectedNodeId: '--', selectedNodeName: '--');

  String _safeLogValue(String? value) {
    final sanitized = (value == null || value.trim().isEmpty ? '--' : value.trim()).replaceAll(
      RegExp(r'https?://[^\s]+'),
      'https://***',
    );
    if (sanitized.length > 64) return '${sanitized.substring(0, 64)}…';
    return sanitized;
  }

  String _safeError(Object? error) {
    final sanitized = error
        .toString()
        .replaceAll(RegExp(r'https?://[^\s,)\]]+'), 'https://***')
        .replaceAllMapped(RegExp(r'(token=)[^&\s,)\]]+', caseSensitive: false), (match) => '${match.group(1)}***')
        .replaceAllMapped(
          RegExp(r'(password|passwd|pwd)=([^&\s,)\]]+)', caseSensitive: false),
          (match) => '${match.group(1)}=***',
        )
        .replaceAllMapped(
          RegExp(r'(authorization|auth_data|authData)\s*[:=]\s*[^\s,)\]]+', caseSensitive: false),
          (match) => '${match.group(1)}=***',
        );
    if (sanitized.length > 160) return '${sanitized.substring(0, 160)}…';
    return sanitized;
  }
}

extension AuthAsyncValueX on AsyncValue<AuthState> {
  String? readableError(TranslationsEn t) {
    return switch (this) {
      AsyncError(:final error) => t.presentError(error).type,
      _ => null,
    };
  }
}
