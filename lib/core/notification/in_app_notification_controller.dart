import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:toastification/toastification.dart';

part 'in_app_notification_controller.g.dart';

@Riverpod(keepAlive: true)
InAppNotificationController inAppNotificationController(Ref ref) {
  return InAppNotificationController();
}

enum NotificationType { info, error, success }

class InAppNotificationController with AppLogger {
  ToastificationItem? _show(
    String message, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    loggy.debug('in-app toast suppressed: type=${type.name}, duration=${duration.inMilliseconds}ms, message=$message');
    return null;
  }

  ToastificationItem? showErrorToast(String message) =>
      _show(message, type: NotificationType.error, duration: const Duration(seconds: 5));

  ToastificationItem? showSuccessToast(String message) => _show(message, type: NotificationType.success);

  ToastificationItem? showInfoToast(String message, {Duration duration = const Duration(seconds: 3)}) =>
      _show(message, duration: duration);
}
