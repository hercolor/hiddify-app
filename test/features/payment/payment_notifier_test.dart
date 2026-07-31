import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/core/notification/in_app_notification_controller.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/auth_state.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/payment/data/payment_api_service.dart';
import 'package:hiddify/features/payment/model/payment_models.dart';
import 'package:hiddify/features/payment/notifier/payment_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toastification/toastification.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('retries checkout with the existing order after a post-order failure', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _RetryablePaymentApi(failFirstPaymentMethods: true);
    Uri? launchedUri;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        paymentApiServiceProvider.overrideWith((ref) => api),
        paymentUriLauncherProvider.overrideWithValue((uri) async {
          launchedUri = uri;
          return true;
        }),
        inAppNotificationControllerProvider.overrideWithValue(_SilentNotifications()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedPreferencesProvider.future);
    await container.read(authNotifierProvider.future);

    final notifier = container.read(paymentNotifierProvider.notifier);
    await notifier.startPurchase(planId: 7, period: 'month_price', planName: 'Monthly');

    expect(container.read(paymentNotifierProvider).stage, PaymentStage.failed);
    expect(container.read(paymentNotifierProvider).tradeNo, 'ORDER123');
    expect(api.createOrderCalls, 1);

    await notifier.retryPendingCheckout();

    final state = container.read(paymentNotifierProvider);
    expect(state.stage, PaymentStage.awaitingBrowser);
    expect(state.tradeNo, 'ORDER123');
    expect(api.createOrderCalls, 1);
    expect(api.fetchOrderCalls, 1);
    expect(api.fetchPaymentMethodsCalls, 2);
    expect(api.checkoutCalls, 1);
    expect(launchedUri, Uri.parse('https://pay.example.test/ORDER123'));
  });

  test('reopens a restored pending order without creating a duplicate', () async {
    SharedPreferences.setMockInitialValues({'payment.pending_trade_no': 'RESTORED1'});
    final preferences = await SharedPreferences.getInstance();
    final api = _RetryablePaymentApi(orderNo: 'RESTORED1');
    Uri? launchedUri;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        paymentApiServiceProvider.overrideWith((ref) => api),
        paymentUriLauncherProvider.overrideWithValue((uri) async {
          launchedUri = uri;
          return true;
        }),
        inAppNotificationControllerProvider.overrideWithValue(_SilentNotifications()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedPreferencesProvider.future);
    await container.read(authNotifierProvider.future);

    final notifier = container.read(paymentNotifierProvider.notifier);
    expect(container.read(paymentNotifierProvider).stage, PaymentStage.awaitingBrowser);

    await notifier.retryPendingCheckout();

    expect(container.read(paymentNotifierProvider).stage, PaymentStage.awaitingBrowser);
    expect(api.createOrderCalls, 0);
    expect(api.fetchOrderCalls, 1);
    expect(api.checkoutCalls, 1);
    expect(launchedUri, Uri.parse('https://pay.example.test/RESTORED1'));
  });

  test('rejects malformed payment URLs before calling the launcher', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final api = _RetryablePaymentApi(checkoutUrl: 'https:///missing-host?token=SECRET');
    var launcherCalled = false;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => preferences),
        authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
        paymentApiServiceProvider.overrideWith((ref) => api),
        paymentUriLauncherProvider.overrideWithValue((uri) async {
          launcherCalled = true;
          return true;
        }),
        inAppNotificationControllerProvider.overrideWithValue(_SilentNotifications()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedPreferencesProvider.future);
    await container.read(authNotifierProvider.future);

    await container
        .read(paymentNotifierProvider.notifier)
        .startPurchase(planId: 7, period: 'month_price', planName: 'Monthly');

    expect(container.read(paymentNotifierProvider).stage, PaymentStage.failed);
    expect(launcherCalled, isFalse);
  });
}

class _RetryablePaymentApi implements PaymentApiService {
  _RetryablePaymentApi({this.failFirstPaymentMethods = false, this.orderNo = 'ORDER123', this.checkoutUrl});

  final bool failFirstPaymentMethods;
  final String orderNo;
  final String? checkoutUrl;
  int createOrderCalls = 0;
  int fetchOrderCalls = 0;
  int fetchPaymentMethodsCalls = 0;
  int checkoutCalls = 0;

  @override
  Future<String> createOrder(String authData, {required int planId, required String period}) async {
    createOrderCalls += 1;
    return orderNo;
  }

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods(String authData) async {
    fetchPaymentMethodsCalls += 1;
    if (failFirstPaymentMethods && fetchPaymentMethodsCalls == 1) {
      throw StateError('temporary method failure');
    }
    return const [PaymentMethod(id: 1, name: 'Online')];
  }

  @override
  Future<PaymentCheckout> checkout(String authData, {required String tradeNo, int? methodId}) async {
    checkoutCalls += 1;
    return PaymentCheckout(tradeNo: tradeNo, payUrl: checkoutUrl ?? 'https://pay.example.test/$tradeNo');
  }

  @override
  Future<PaymentOrder> fetchOrder(String authData, {required String tradeNo}) async {
    fetchOrderCalls += 1;
    return PaymentOrder(tradeNo: tradeNo, status: PaymentOrderStatus.pending);
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthState.loggedIn(
    AuthSession(authData: 'Bearer test-token', email: 'test@example.test', createdAt: DateTime(2030)),
  );

  @override
  Future<void> refreshSubscription({bool showSuccessToast = true, bool showFailureToast = true}) async {}
}

class _SilentNotifications extends InAppNotificationController {
  @override
  ToastificationItem? showErrorToast(String message) => null;

  @override
  ToastificationItem? showInfoToast(String message, {Duration duration = const Duration(milliseconds: 1800)}) => null;

  @override
  ToastificationItem? showSuccessToast(String message) => null;
}
