import 'dart:async';

import 'package:dartx/dartx.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
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
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final loginService = await ref.read(loginServiceProvider.future);
      final session = await loginService
          .login(email: email, password: password)
          .match((err) => throw err, (session) => session)
          .run();

      await ref.read(authTokenStorageProvider).save(session);
      var syncedSession = session;
      var syncSucceeded = false;
      try {
        syncedSession = await _fetchSubscriptionAndImport(session);
        syncSucceeded = true;
      } catch (error, stackTrace) {
        loggy.warning('failed to sync xboard nodes after login', error, stackTrace);
        ref.read(inAppNotificationControllerProvider).showErrorToast('节点同步失败，正在使用本地缓存');
      }
      await ref.read(authTokenStorageProvider).save(syncedSession);
      if (syncSucceeded) {
        ref.read(inAppNotificationControllerProvider).showSuccessToast('登录成功');
      }
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
      final session = await _fetchSubscriptionAndImport(current);
      await ref.read(authTokenStorageProvider).save(session);
      final nextState = AuthState.loggedIn(session);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: true);
      if (showSuccessToast) {
        ref.read(inAppNotificationControllerProvider).showSuccessToast('节点已同步');
      }
      return true;
    } catch (error, stackTrace) {
      loggy.warning('failed to sync xboard nodes', error, stackTrace);
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

  Future<AuthSession> _fetchSubscriptionAndImport(AuthSession session) async {
    final subscriptionService = await ref.read(userSubscriptionServiceProvider.future);
    final syncUserWatch = Stopwatch()..start();
    final subscription = await subscriptionService
        .fetchSubscription(session.authData)
        .match((err) => throw err, (subscription) => subscription)
        .run();
    syncUserWatch.stop();
    final syncNodesWatch = Stopwatch()..start();
    final subscriptionUrl = subscription.subscribeUrl.trim();
    loggy.info(
      'xboard subscription ready: '
      'urlExists=${subscriptionUrl.isNotEmpty}, '
      'urlLength=${subscriptionUrl.length}, '
      'planExists=${subscription.planName?.trim().isNotEmpty == true}, '
      'hasTraffic=${subscription.hasTrafficInfo}',
    );

    final repo = await ref.read(profileRepositoryProvider.future);
    await repo.upsertRemote(subscriptionUrl).match((err) => throw err, (_) => unit).run();
    ref.invalidate(activeProfileProvider);
    final nodeSummary = await _cacheNodesFromActiveProfile(repo);
    syncNodesWatch.stop();
    loggy.info(
      'xboard nodes imported from subscription url, '
      'urlLength=${subscriptionUrl.length}, '
      'nodeCount=${nodeSummary.nodeCount}, '
      'selectedNodeId=${nodeSummary.selectedNodeId}, '
      'selectedNodeName=${nodeSummary.selectedNodeName}, '
      'syncUserMs=${syncUserWatch.elapsedMilliseconds}, '
      'syncNodesMs=${syncNodesWatch.elapsedMilliseconds}',
    );
    return session.copyWith(subscription: subscription);
  }

  Future<void> _syncNodesInBackground(AuthSession session) async {
    try {
      final syncedSession = await _fetchSubscriptionAndImport(session);
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
      final nodes = ClientNodeParser.parse(rawConfig);
      if (nodes.isNotEmpty) {
        await ref.read(clientNodeSelectionProvider.notifier).cacheNodes(nodes, profileName: profile.name);
      }
      final selection =
          ref.read(clientNodeSelectionProvider).valueOrNull ??
          await ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
      return _nodeDebugFromSelection(selection.copyWith(profileName: profile.name));
    } catch (error, stackTrace) {
      loggy.debug('failed to cache sanitized node summary', error, stackTrace);
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
}

extension AuthAsyncValueX on AsyncValue<AuthState> {
  String? readableError(TranslationsEn t) {
    return switch (this) {
      AsyncError(:final error) => t.presentError(error).type,
      _ => null,
    };
  }
}
