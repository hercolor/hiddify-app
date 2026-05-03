import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
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
      final subscriptionService = await ref.read(userSubscriptionServiceProvider.future);

      final session = await loginService
          .login(email: email, password: password)
          .flatMap(
            (session) => subscriptionService
                .fetchSubscription(session.token)
                .map((subscription) => session.copyWith(subscription: subscription)),
          )
          .match((err) => throw err, (session) => session)
          .run();

      await ref.read(authTokenStorageProvider).save(session);
      ref.read(inAppNotificationControllerProvider).showSuccessToast('登录成功');
      return AuthState(session: session);
    });
  }

  Future<void> refreshSubscription() async {
    if (state.isLoading) return;
    final current = state.valueOrNull?.session;
    if (current == null) {
      state = AsyncError(const AuthFailure.notLoggedIn(), StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final subscriptionService = await ref.read(userSubscriptionServiceProvider.future);
      final session = await subscriptionService
          .fetchSubscription(current.token)
          .match((err) => throw err, (subscription) => current.copyWith(subscription: subscription))
          .run();

      await ref.read(authTokenStorageProvider).save(session);
      ref.read(inAppNotificationControllerProvider).showSuccessToast('订阅信息已更新');
      return AuthState(session: session);
    });
  }

  Future<void> importSubscriptionToProfiles() async {
    if (state.isLoading) return;
    final current = state.valueOrNull?.session;
    final subscriptionUrl = current?.subscription?.subscribeUrl;
    if (current == null || subscriptionUrl == null || subscriptionUrl.isEmpty) {
      state = AsyncError(const AuthFailure.notLoggedIn(), StackTrace.current);
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = await ref.read(profileRepositoryProvider.future);
      await repo.upsertRemote(subscriptionUrl).match((err) => throw err, (_) => unit).run();
      ref.read(inAppNotificationControllerProvider).showSuccessToast('订阅已导入');
      return AuthState(session: current);
    });
  }

  Future<void> logout() async {
    await ref.read(authTokenStorageProvider).clear();
    state = const AsyncData(AuthState());
    ref.read(inAppNotificationControllerProvider).showSuccessToast('已退出登录');
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
