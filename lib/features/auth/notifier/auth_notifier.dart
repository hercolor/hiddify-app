import 'dart:async';
import 'dart:convert';

import 'package:dartx/dartx.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
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

final _fallbackAuthText = AppLocale.en.buildSync();

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier with AppLogger {
  Translations get _authText => ref.read(translationsProvider).valueOrNull ?? _fallbackAuthText;

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
        loggy.debug('auth bootstrapMs=${bootstrapWatch.elapsedMilliseconds}');
        return nextState;
      }

      final nextState = AuthState.loggedIn(session);
      await _logAuthDebug(nextState, userInfoLoaded: session.subscription != null);
      unawaited(_syncNodesInBackground(session));
      loggy.debug('auth bootstrapMs=${bootstrapWatch.elapsedMilliseconds}');
      return nextState;
    } catch (error, stackTrace) {
      loggy.warning('auth bootstrap failed', error, stackTrace);
      const nextState = AuthState.loggedOut();
      await _logAuthDebug(nextState, userInfoLoaded: false);
      loggy.debug('auth bootstrapMs=${bootstrapWatch.elapsedMilliseconds}');
      return nextState;
    } finally {
      bootstrapWatch.stop();
    }
  }

  Future<void> login(String account, String password) async {
    if (state.isLoading) return;
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final loginService = await ref.read(loginServiceProvider.future);
      final session = await loginService
          .login(account: account, password: password)
          .match((err) => throw err, (session) => session)
          .run();

      return _completeAuthenticatedSession(
        session,
        successMessage: _authText.errors.auth.loginSuccess,
        fallbackSuccessMessage: _authText.errors.auth.loggedIn,
      );
    });
  }

  Future<void> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  }) async {
    if (state.isLoading) return;
    state = const AsyncLoading<AuthState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final loginService = await ref.read(loginServiceProvider.future);
      final session = await loginService
          .register(email: email, password: password, emailCode: emailCode, inviteCode: inviteCode)
          .match((err) => throw err, (session) => session)
          .run();

      return _completeAuthenticatedSession(
        session,
        successMessage: _authText.errors.auth.registerSuccess,
        fallbackSuccessMessage: _authText.errors.auth.registered,
      );
    });
  }

  Future<AuthState> _completeAuthenticatedSession(
    AuthSession session, {
    required String successMessage,
    required String fallbackSuccessMessage,
  }) async {
    await ref.read(authTokenStorageProvider).save(session);
    var syncedSession = session;
    var userInfoSynced = false;
    Object? syncError;
    try {
      final result = await _fetchSubscriptionAndImport(session);
      syncedSession = result.session;
      userInfoSynced = true;
    } catch (error, stackTrace) {
      syncError = error;
      loggy.warning('failed to sync user info after auth', error, stackTrace);
      DiagnosticEventBuffer.add('user info sync after auth failed: ${_safeError(error)}');
      if (_isSubscriptionUnavailable(error)) {
        await _clearSubscriptionAccessCache(session: session, reason: _safeError(error));
        syncedSession = session.copyWith(clearSubscription: true);
      }
      ref.read(inAppNotificationControllerProvider).showErrorToast(_loginSyncErrorMessage(error));
    }
    await ref.read(authTokenStorageProvider).save(syncedSession);
    if (syncError == null) {
      ref
          .read(inAppNotificationControllerProvider)
          .showSuccessToast(userInfoSynced ? successMessage : fallbackSuccessMessage);
    }
    final nextState = AuthState.loggedIn(syncedSession);
    await _logAuthDebug(nextState, userInfoLoaded: syncedSession.subscription != null);
    return nextState;
  }

  Future<void> refreshSubscription({bool showSuccessToast = true, bool showFailureToast = true}) async {
    await syncNodes(showSuccessToast: showSuccessToast, showFailureToast: showFailureToast);
  }

  Future<String?> ensureSubscriptionAccessForConnect() async {
    final current = state.valueOrNull?.session;
    if (current == null) {
      return _authText.errors.auth.notLoggedIn;
    }

    try {
      final result = await _fetchSubscriptionAndImport(current, showNodeFailureToast: false);
      final session = result.session;
      if (!_isCurrentSession(current)) return _authText.errors.auth.notLoggedIn;
      await ref.read(authTokenStorageProvider).save(session);
      final nextState = AuthState.loggedIn(session);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: session.subscription != null);

      final subscription = session.subscription;
      if (subscription == null) {
        return _authText.errors.auth.openMembership;
      }
      if (!subscription.canConnect) {
        await _clearSubscriptionAccessCache(session: session, reason: 'membership unavailable before connect');
        return _subscriptionAccessFailureMessage(subscription);
      }
      if (subscription.isExpired) {
        await _clearSubscriptionAccessCache(session: session, reason: 'expired before connect');
        return _authText.errors.auth.membershipExpired;
      }
      if (subscription.isTrafficExhausted) {
        await _clearSubscriptionAccessCache(session: session, reason: 'traffic exhausted before connect');
        return _authText.errors.auth.trafficExhausted;
      }
      return null;
    } catch (error, stackTrace) {
      loggy.warning('subscription access check before connect failed', error, stackTrace);
      DiagnosticEventBuffer.add('subscription access check before connect failed: ${_safeError(error)}');
      if (_isSubscriptionUnavailable(error)) {
        final message = _subscriptionUnavailableErrorMessage(error, cachedSubscription: current.subscription);
        await _markSubscriptionUnavailable(current, reason: _safeError(error));
        return message;
      }

      final cachedSubscription = current.subscription;
      if (cachedSubscription != null && !cachedSubscription.canConnect) {
        return _subscriptionAccessFailureMessage(cachedSubscription);
      }
      return _authText.errors.auth.accessCheckFailed;
    }
  }

  Future<bool> syncNodes({bool showSuccessToast = true, bool showFailureToast = true}) async {
    final current = state.valueOrNull?.session;
    if (current == null) {
      ref.read(inAppNotificationControllerProvider).showErrorToast(_authText.errors.auth.notLoggedIn);
      return false;
    }

    try {
      final result = await _fetchSubscriptionAndImport(current, showNodeFailureToast: showSuccessToast);
      final session = result.session;
      if (!_isCurrentSession(current)) return false;
      await ref.read(authTokenStorageProvider).save(session);
      final nextState = AuthState.loggedIn(session);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: true);
      if (showSuccessToast) {
        if (result.nodesSynced) {
          ref.read(inAppNotificationControllerProvider).showSuccessToast(_authText.errors.auth.nodesSynced);
        }
      }
      return result.nodesSynced;
    } catch (error, stackTrace) {
      loggy.warning('failed to sync nodes', error, stackTrace);
      DiagnosticEventBuffer.add('node sync failed: ${_safeError(error)}');
      if (_isSubscriptionUnavailable(error)) {
        await _markSubscriptionUnavailable(current, reason: _safeError(error));
      }
      if (!_isCurrentSession(current)) return false;
      final nextState = AuthState.loggedIn(state.valueOrNull?.session ?? current);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: nextState.session?.subscription != null);
      if (showFailureToast) {
        final cachedNodes = await _safeReadCachedNodes();
        ref
            .read(inAppNotificationControllerProvider)
            .showErrorToast(_nodeSyncErrorMessage(error, hasCachedNodes: cachedNodes.nodeCount > 0));
      }
      return false;
    }
  }

  Future<void> importSubscriptionToProfiles() async {
    await syncNodes();
  }

  Future<void> logout() async {
    await ref.read(authTokenStorageProvider).clear();
    await ref.read(clientNodeSelectionProvider.notifier).clear();
    state = const AsyncData(AuthState.loggedOut());
    await _logAuthDebug(const AuthState.loggedOut(), userInfoLoaded: false);
    ref.read(inAppNotificationControllerProvider).showSuccessToast(_authText.errors.auth.loggedOut);
  }

  Future<void> sendPhoneBindVerify(String phone) async {
    final session = state.valueOrNull?.session;
    if (session == null) {
      ref.read(inAppNotificationControllerProvider).showErrorToast(_authText.errors.auth.notLoggedIn);
      return;
    }
    final loginService = await ref.read(loginServiceProvider.future);
    await loginService
        .sendPhoneBindVerify(authData: session.authData, phone: phone)
        .match((err) => throw err, (_) => unit)
        .run();
    ref.read(inAppNotificationControllerProvider).showSuccessToast(_authText.errors.auth.phoneVerifySent);
  }

  Future<void> changePassword({required String oldPassword, required String newPassword}) async {
    final session = state.valueOrNull?.session;
    if (session == null) {
      ref.read(inAppNotificationControllerProvider).showErrorToast(_authText.errors.auth.notLoggedIn);
      return;
    }
    final loginService = await ref.read(loginServiceProvider.future);
    await loginService
        .changePassword(authData: session.authData, oldPassword: oldPassword, newPassword: newPassword)
        .match((err) => throw err, (_) => unit)
        .run();
    ref.read(inAppNotificationControllerProvider).showSuccessToast(_authText.errors.auth.passwordChanged);
  }

  Future<void> bindPhone({required String phone, required String phoneCode}) async {
    final session = state.valueOrNull?.session;
    if (session == null) {
      ref.read(inAppNotificationControllerProvider).showErrorToast(_authText.errors.auth.notLoggedIn);
      return;
    }
    final loginService = await ref.read(loginServiceProvider.future);
    final boundPhone = await loginService
        .bindPhone(authData: session.authData, phone: phone, phoneCode: phoneCode)
        .match((err) => throw err, (phone) => phone)
        .run();
    final nextSession = session.copyWith(phone: boundPhone);
    await ref.read(authTokenStorageProvider).save(nextSession);
    state = AsyncData(AuthState.loggedIn(nextSession));
    ref.read(inAppNotificationControllerProvider).showSuccessToast(_authText.errors.auth.phoneBound);
  }

  Future<({AuthSession session, bool nodesSynced})> _fetchSubscriptionAndImport(
    AuthSession session, {
    bool showNodeFailureToast = true,
  }) async {
    final subscriptionService = await ref.read(userSubscriptionServiceProvider.future);
    final syncUserWatch = Stopwatch()..start();
    final subscription = await subscriptionService
        .fetchSubscription(
          session.authData,
          subscribeToken: session.subscribeToken,
          fallbackSubscribeUrl: session.subscription?.subscribeUrl,
        )
        .match((err) => throw err, (subscription) => subscription)
        .run();
    syncUserWatch.stop();
    final subscriptionUrl = subscription.subscribeUrl.trim();
    if (subscriptionUrl.isEmpty && subscription.canConnect) {
      throw AuthFailure.serverMessage(_authText.errors.auth.subscriptionEmpty);
    }
    var syncedSession = session.copyWith(subscription: subscription);
    final boundPhone = await _safeFetchBoundPhone(syncedSession.authData);
    if (boundPhone != null) {
      syncedSession = syncedSession.copyWith(phone: boundPhone);
    }
    await ref.read(authTokenStorageProvider).save(syncedSession);
    loggy.info(
      'subscription data ready: '
      'urlExists=${subscriptionUrl.isNotEmpty}, '
      'urlLength=${subscriptionUrl.length}, '
      'planExists=${subscription.planName?.trim().isNotEmpty == true}, '
      'hasTraffic=${subscription.hasTrafficInfo}',
    );
    DiagnosticEventBuffer.add(
      'subscription data ready: urlExists=${subscriptionUrl.isNotEmpty}, '
      'urlLength=${subscriptionUrl.length}, planExists=${subscription.planName?.trim().isNotEmpty == true}, '
      'hasTraffic=${subscription.hasTrafficInfo}',
    );

    if (!subscription.canConnect) {
      await _clearSubscriptionAccessCache(session: syncedSession, reason: 'membership unavailable during sync');
      loggy.info(
        'membership unavailable, node sync skipped: '
        'membershipStatus=${subscription.membershipStatus}, '
        'subscriptionStatus=${subscription.subscriptionStatus}, '
        'canConnect=${subscription.canConnect}',
      );
      DiagnosticEventBuffer.add(
        'membership unavailable, node sync skipped: '
        'membershipStatus=${subscription.membershipStatus}, subscriptionStatus=${subscription.subscriptionStatus}',
      );
      return (session: syncedSession, nodesSynced: false);
    }

    final syncNodesWatch = Stopwatch()..start();
    var nodesSynced = false;
    var nodeSummary = _nodeDebugFallback();
    final cachedBefore = await _safeReadCachedNodes();
    if (cachedBefore.nodeCount > 0) {
      nodeSummary = _nodeDebugFromSelection(cachedBefore);
    }

    try {
      final nodes = await _downloadAndCacheNodes(subscriptionUrl);
      if (nodes.isNotEmpty) {
        nodesSynced = true;
        nodeSummary = await _readNodeDebugSummary();
      }
    } catch (error, stackTrace) {
      loggy.warning('failed to parse nodes from subscription content: ${_safeError(error)}', null, stackTrace);
      DiagnosticEventBuffer.add('subscription node parse failed: ${_safeError(error)}');
    }

    try {
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.upsertRemote(subscriptionUrl).match((err) => throw err, (_) => unit).run();
      loggy.debug('remote profile import succeeded');
      DiagnosticEventBuffer.add('remote profile import succeeded');
      ref.invalidate(activeProfileProvider);
      final importedSummary = await _cacheNodesFromActiveProfile(repo);
      if (importedSummary.nodeCount > 0) {
        nodeSummary = importedSummary;
        nodesSynced = true;
      }
      if (nodeSummary.nodeCount == 0) {
        loggy.info('node cache is empty after import; core will refresh visible nodes on connect');
        DiagnosticEventBuffer.add('node cache empty after import; visible nodes will refresh when core starts');
      }
    } catch (error, stackTrace) {
      loggy.warning('failed to import nodes, preserving user subscription: ${_safeError(error)}', null, stackTrace);
      DiagnosticEventBuffer.add('remote profile import failed: ${_safeError(error)}');
    }

    final cachedAfter = await _safeReadCachedNodes();
    if (!nodesSynced && cachedAfter.nodeCount > 0) {
      nodeSummary = _nodeDebugFromSelection(cachedAfter);
    }
    if (!nodesSynced && showNodeFailureToast) {
      ref
          .read(inAppNotificationControllerProvider)
          .showErrorToast(
            cachedAfter.nodeCount > 0
                ? _authText.errors.auth.nodeSyncFailedUsingCache
                : _authText.errors.auth.fetchNodesFailed,
          );
    }
    syncNodesWatch.stop();
    loggy.info(
      'node sync completed, '
      'urlLength=${subscriptionUrl.length}, '
      'nodeCount=${nodeSummary.nodeCount}, '
      'selectedNodeId=${nodeSummary.selectedNodeId}, '
      'selectedNodeName=${nodeSummary.selectedNodeName}, '
      'nodesSynced=$nodesSynced, '
      'syncUserMs=${syncUserWatch.elapsedMilliseconds}, '
      'syncNodesMs=${syncNodesWatch.elapsedMilliseconds}',
    );
    DiagnosticEventBuffer.add(
      'node sync completed: nodeCount=${nodeSummary.nodeCount}, '
      'selectedNodeName=${nodeSummary.selectedNodeName}, profileImported=$nodesSynced, '
      'syncUserMs=${syncUserWatch.elapsedMilliseconds}, syncNodesMs=${syncNodesWatch.elapsedMilliseconds}',
    );
    return (session: syncedSession, nodesSynced: nodesSynced);
  }

  Future<String?> _safeFetchBoundPhone(String authData) async {
    try {
      final loginService = await ref.read(loginServiceProvider.future);
      return loginService.fetchBoundPhone(authData: authData).match((err) => null, (phone) => phone).run();
    } catch (error, stackTrace) {
      loggy.debug('bound phone fetch skipped', error, stackTrace);
      return null;
    }
  }

  Future<List<ClientNode>> _downloadAndCacheNodes(String subscriptionUrl) async {
    final response = await ref.read(httpClientProvider).get<Object?>(subscriptionUrl, headers: const {'Accept': '*/*'});
    if ((response.statusCode ?? 0) >= 400) {
      throw AuthFailure.badResponse('HTTP ${response.statusCode}');
    }
    final content = _subscriptionContentToText(response.data);
    final nodes = ClientNodeParser.parse(content);
    DiagnosticEventBuffer.add(
      'subscription content parsed: nodeCount=${nodes.length}, contentLength=${content.length}',
    );
    loggy.info('subscription content parsed: nodeCount=${nodes.length}, contentLength=${content.length}');
    if (nodes.isNotEmpty) {
      await ref.read(clientNodeSelectionProvider.notifier).cacheNodes(nodes, profileName: '蝴蝶加速');
    }
    return nodes;
  }

  String _subscriptionContentToText(Object? data) {
    if (data == null) return '';
    if (data is String) return data;
    if (data is List<int>) return utf8.decode(data, allowMalformed: true);
    if (data is List) {
      final bytes = data.whereType<int>().toList(growable: false);
      if (bytes.length == data.length) return utf8.decode(bytes, allowMalformed: true);
    }
    if (data is Map || data is Iterable) return jsonEncode(data);
    return data.toString();
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
      loggy.warning('failed to sync nodes during bootstrap', error, stackTrace);
      if (!_isCurrentSession(session)) return;
      if (_isSubscriptionUnavailable(error)) {
        await _markSubscriptionUnavailable(session, reason: _safeError(error));
      }
      final nextState = AuthState.loggedIn(state.valueOrNull?.session ?? session);
      state = AsyncData(nextState);
      await _logAuthDebug(nextState, userInfoLoaded: nextState.session?.subscription != null);
      final cachedNodes = await _safeReadCachedNodes();
      ref
          .read(inAppNotificationControllerProvider)
          .showErrorToast(_nodeSyncErrorMessage(error, hasCachedNodes: cachedNodes.nodeCount > 0));
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
      'auth debug: '
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
        await ref.read(clientNodeSelectionProvider.notifier).cacheNodes(nodes, profileName: '蝴蝶加速');
      }
      final selection =
          ref.read(clientNodeSelectionProvider).valueOrNull ??
          await ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
      final summary = _nodeDebugFromSelection(selection.copyWith(profileName: '蝴蝶加速'));
      DiagnosticEventBuffer.add(
        'node cache parsed: source=$source, profileName=${summary.profileName}, '
        'nodeCount=${summary.nodeCount}, selectedNodeName=${summary.selectedNodeName}',
      );
      return summary;
    } catch (error, stackTrace) {
      loggy.debug('failed to cache sanitized node summary', error, stackTrace);
      DiagnosticEventBuffer.add('node cache failed: ${_safeError(error)}');
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

  Future<ClientNodeSelection> _safeReadCachedNodes() async {
    try {
      return await ref.read(clientNodeSelectionProvider.notifier).ensureLoaded();
    } catch (error, stackTrace) {
      loggy.debug('failed to read cached nodes', error, stackTrace);
      return const ClientNodeSelection.empty();
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

  String _loginSyncErrorMessage(Object error) {
    return switch (error) {
      AuthServerMessageFailure(:final message) => message,
      AuthBadResponseFailure(:final message?) when message.trim().isNotEmpty => message,
      _ => _authText.errors.auth.loginSyncFailed,
    };
  }

  String _nodeSyncErrorMessage(Object error, {required bool hasCachedNodes}) {
    return switch (error) {
      AuthServerMessageFailure(:final message) => message,
      _ when hasCachedNodes => _authText.errors.auth.nodeSyncFailedUsingCache,
      _ => _authText.errors.auth.fetchNodesFailed,
    };
  }

  String _subscriptionUnavailableErrorMessage(Object error, {UserSubscription? cachedSubscription}) {
    if (cachedSubscription != null && !cachedSubscription.canConnect) {
      return _subscriptionAccessFailureMessage(cachedSubscription);
    }
    final text = _safeError(error).toLowerCase();
    final looksExpired = text.contains('到期') || text.contains('过期') || text.contains('expired');
    final looksTraffic = text.contains('流量') || text.contains('traffic');
    if (looksExpired && looksTraffic) return _authText.errors.auth.membershipExpiredOrTraffic;
    if (looksTraffic) return _authText.errors.auth.trafficExhausted;
    if (looksExpired) return _authText.errors.auth.membershipExpired;
    return _authText.errors.auth.openMembership;
  }

  String _subscriptionAccessFailureMessage(UserSubscription subscription) {
    if (subscription.isNormalUser) return _authText.errors.auth.openMembership;
    if (subscription.isSubscriptionExpired) return _authText.errors.auth.membershipExpired;
    if (subscription.isTrafficUnavailable) return _authText.errors.auth.trafficExhausted;
    if (subscription.isBanned) return _authText.errors.auth.badResponse;
    return _authText.errors.auth.openMembership;
  }

  bool _isSubscriptionUnavailable(Object error) {
    final text = _safeError(error).toLowerCase();
    return text.contains('会员') ||
        text.contains('到期') ||
        text.contains('过期') ||
        text.contains('expired') ||
        text.contains('unavailable') ||
        text.contains('traffic') ||
        text.contains('流量');
  }

  Future<void> _markSubscriptionUnavailable(AuthSession session, {required String reason}) async {
    if (!_isCurrentSession(session)) return;
    await _clearSubscriptionAccessCache(session: session, reason: reason);
    final unavailableSubscription = _subscriptionMarkedUnavailable(session.subscription, reason: reason);
    final unavailableSession = unavailableSubscription == null
        ? session.copyWith(clearSubscription: true)
        : session.copyWith(subscription: unavailableSubscription);
    await ref.read(authTokenStorageProvider).save(unavailableSession);
    state = AsyncData(AuthState.loggedIn(unavailableSession));
    await _logAuthDebug(AuthState.loggedIn(unavailableSession), userInfoLoaded: unavailableSubscription != null);
  }

  UserSubscription? _subscriptionMarkedUnavailable(UserSubscription? subscription, {required String reason}) {
    if (subscription == null) return null;
    final normalized = reason.toLowerCase();
    final looksExpired =
        normalized.contains('会员') ||
        normalized.contains('到期') ||
        normalized.contains('过期') ||
        normalized.contains('expired') ||
        normalized.contains('unavailable');
    if (!looksExpired && subscription.isExpired) return subscription;
    if (!looksExpired) return subscription;
    return subscription.copyWith(
      expiredAt: DateTime.now(),
      membershipStatus: 'expired',
      membershipLabel: _authText.errors.auth.membershipExpiredLabel,
      subscriptionStatus: 'expired',
      serverCanConnect: false,
    );
  }

  Future<void> _clearSubscriptionAccessCache({required AuthSession session, required String reason}) async {
    DiagnosticEventBuffer.addSafe('subscription access cache cleared: $reason');
    await ref.read(clientNodeSelectionProvider.notifier).clear();
    try {
      final activeProfile = await ref
          .read(activeProfileProvider.future)
          .timeout(const Duration(seconds: 1), onTimeout: () => null);
      if (activeProfile case RemoteProfileEntity(
        :final id,
        :final active,
        :final url,
      ) when _isAccountSubscriptionProfile(url, session.subscription?.subscribeUrl)) {
        final repo = await ref.read(profileRepositoryProvider.future);
        await repo.deleteById(id, active).match((err) => null, (_) => unit).run();
        ref.invalidate(activeProfileProvider);
      }
    } catch (error, stackTrace) {
      loggy.debug('failed to clear active subscription profile', error, stackTrace);
    }
  }

  bool _isAccountSubscriptionProfile(String profileUrl, String? subscriptionUrl) {
    final profile = profileUrl.trim();
    final subscription = subscriptionUrl?.trim();
    if (subscription != null && subscription.isNotEmpty && profile == subscription) return true;
    final uri = Uri.tryParse(profile);
    return uri?.path.toLowerCase().endsWith('/api/v1/client/subscribe') == true;
  }
}

extension AuthAsyncValueX on AsyncValue<AuthState> {
  String? readableError(TranslationsEn t) {
    return switch (this) {
      AsyncError(:final error) => _formatAuthError(t.presentError(error)),
      _ => null,
    };
  }

  String _formatAuthError(({String type, String? message}) pair) {
    final message = pair.message?.trim();
    if (message == null || message.isEmpty) return pair.type;
    return '${pair.type}\n$message';
  }
}
