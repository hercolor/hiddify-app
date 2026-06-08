import 'package:flutter/material.dart';
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
  String? _lastMessage;
  DateTime? _lastShownAt;

  ToastificationItem? _show(
    String message, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(milliseconds: 1800),
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return null;
    final now = DateTime.now();
    final lastShownAt = _lastShownAt;
    if (_lastMessage == trimmed && lastShownAt != null && now.difference(lastShownAt) < const Duration(seconds: 1)) {
      loggy.debug('in-app toast skipped duplicate: type=${type.name}, message=$trimmed');
      return null;
    }
    _lastMessage = trimmed;
    _lastShownAt = now;
    toastification.dismissAll(delayForAnimation: false);
    final effectiveDuration = duration > const Duration(milliseconds: 2500)
        ? const Duration(milliseconds: 2500)
        : duration;
    loggy.debug(
      'in-app toast show: type=${type.name}, duration=${effectiveDuration.inMilliseconds}ms, message=$trimmed',
    );
    return toastification.show(
      title: Text(trimmed),
      type: switch (type) {
        NotificationType.info => ToastificationType.info,
        NotificationType.error => ToastificationType.error,
        NotificationType.success => ToastificationType.success,
      },
      alignment: Alignment.bottomCenter,
      autoCloseDuration: effectiveDuration,
      style: ToastificationStyle.fillColored,
      pauseOnHover: true,
      showProgressBar: false,
      dragToClose: true,
      closeOnClick: true,
      closeButtonShowType: CloseButtonShowType.onHover,
    );
  }

  ToastificationItem? showErrorToast(String message) =>
      _show(message, type: NotificationType.error, duration: const Duration(milliseconds: 2500));

  ToastificationItem? showSuccessToast(String message) => _show(message, type: NotificationType.success);

  ToastificationItem? showInfoToast(String message, {Duration duration = const Duration(milliseconds: 1800)}) =>
      _show(message, duration: duration);
}
