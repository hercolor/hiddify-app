import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier with AppLogger {
  @override
  Future<AuthState> build() async {
    final session = await ref.watch(authTokenStorageProvider).read();
    return AuthState(session: session);
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
      final syncedSession = await _fetchSubscriptionAndImport(session);
      await ref.read(authTokenStorageProvider).save(syncedSession);
      ref.read(inAppNotificationControllerProvider).showSuccessToast('登录成功');
      return AuthState(session: syncedSession);
    });
  }

  Future<void> refreshSubscription() async {
    await syncNodes();
  }

  Future<bool> syncNodes({bool showSuccessToast = true}) async {
    if (state.isLoading) return false;
    final current = state.valueOrNull?.session;
    if (current == null) {
      ref.read(inAppNotificationControllerProvider).showErrorToast('请先登录账号');
      return false;
    }

    state = const AsyncLoading();
    try {
      final session = await _fetchSubscriptionAndImport(current);
      await ref.read(authTokenStorageProvider).save(session);
      state = AsyncData(AuthState(session: session));
      if (showSuccessToast) {
        ref.read(inAppNotificationControllerProvider).showSuccessToast('节点已同步');
      }
      return true;
    } catch (error, stackTrace) {
      loggy.warning('failed to sync xboard nodes', error, stackTrace);
      state = AsyncData(AuthState(session: current));
      ref.read(inAppNotificationControllerProvider).showErrorToast('获取节点失败，请稍后重试');
      return false;
    }
  }

  Future<void> importSubscriptionToProfiles() async {
    await syncNodes();
  }

  Future<void> logout() async {
    await ref.read(authTokenStorageProvider).clear();
    state = const AsyncData(AuthState());
    ref.read(inAppNotificationControllerProvider).showSuccessToast('已退出登录');
  }

  Future<AuthSession> _fetchSubscriptionAndImport(AuthSession session) async {
    final subscriptionService = await ref.read(userSubscriptionServiceProvider.future);
    final subscription = await subscriptionService
        .fetchSubscription(session.authData)
        .match((err) => throw err, (subscription) => subscription)
        .run();
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
    loggy.info('xboard nodes imported from subscription url, urlLength=${subscriptionUrl.length}');
    return session.copyWith(subscription: subscription);
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
