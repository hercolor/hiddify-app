import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

part 'window_notifier.g.dart';

const minimumWindowSize = BrandDesktopWindow.minimumSize;
const defaultWindowSize = BrandDesktopWindow.defaultSize;

@Riverpod(keepAlive: true)
class WindowNotifier extends _$WindowNotifier with AppLogger {
  @override
  Future<void> build() async {
    if (!PlatformUtils.isDesktop) return;

    // if (Platform.isWindows) {
    //   loggy.debug("ensuring single instance");
    //   await WindowsSingleInstance.ensureSingleInstance([], "Hiddify");
    // }

    await windowManager.ensureInitialized();
    await initWindowState();
  }

  Future<void> saveWindowState() async {
    if (await windowManager.isMaximized()) {
      await ref.read(Preferences.windowMaximized.notifier).update(true);
    } else {
      final size = await windowManager.getSize();
      final position = await windowManager.getPosition();

      await ref.read(Preferences.windowMaximized.notifier).update(false);
      await ref.read(Preferences.windowSize.notifier).update(size);
      await ref.read(Preferences.windowPosition.notifier).update(position);
    }
  }

  Future<void> initWindowState() async {
    final isMaximized = ref.read(Preferences.windowMaximized);
    loggy.debug("window state. maximized: $isMaximized");
    final size = _sanitizeWindowSize(ref.read(Preferences.windowSize));
    loggy.debug("window state. size: $size");
    final position = ref.read(Preferences.windowPosition);
    final isWindowVisible = position != null && await checkWindowVisivility(position, size);
    loggy.debug("window state. position: ${isWindowVisible ? position : "centered"}");
    final silentStart = ref.read(Preferences.silentStart);
    loggy.debug("window state. silent start: ${silentStart ? "Enabled" : "Disabled"}");

    await windowManager.waitUntilReadyToShow(
      WindowOptions(
        size: size,
        center: !isWindowVisible,
        minimumSize: minimumWindowSize,
        maximumSize: BrandDesktopWindow.maximumSize,
        title: '蝴蝶加速',
      ),
    );
    if (Platform.isWindows) {
      await windowManager.setAspectRatio(BrandDesktopWindow.aspectRatio);
      await windowManager.setResizable(false);
      await windowManager.setMaximizable(false);
      await windowManager.setSize(BrandDesktopWindow.defaultSize);
    }
    if (isWindowVisible) {
      await windowManager.setPosition(position);
      loggy.debug("restoring window to position: $position");
    } else {
      loggy.debug("no previous position found, centering window");
    }
    if (isMaximized && !Platform.isWindows) {
      await windowManager.maximize();
      loggy.debug("restoring window to maximized state");
    }
    if (!silentStart) {
      await windowManager.show();
      await windowManager.focus();
      loggy.debug("showing app window on start, isVisible=${await windowManager.isVisible()}");
    } else {
      loggy.debug("silent start, remain hidden accessible via tray");
    }
  }

  Future<bool> checkWindowVisivility(Offset windowPos, Size windowSize, {double tolerance = 10.0}) async {
    final Rect windowRect = windowPos & windowSize;

    final displays = await screenRetriever.getAllDisplays();

    for (final display in displays) {
      if (display.visiblePosition == null || display.visibleSize == null) {
        continue;
      }
      final Rect monitorRect = display.visiblePosition! & display.visibleSize!;
      if (windowRect.left >= (monitorRect.left - tolerance) &&
          windowRect.top >= (monitorRect.top - tolerance) &&
          windowRect.right <= (monitorRect.right + tolerance) &&
          windowRect.bottom <= (monitorRect.bottom + tolerance)) {
        return true;
      }
    }
    return false;
  }

  Size _sanitizeWindowSize(Size? raw) {
    if (Platform.isWindows) return defaultWindowSize;
    if (raw == null || raw.width <= 0 || raw.height <= 0) return defaultWindowSize;
    final width = raw.width.clamp(minimumWindowSize.width, BrandDesktopWindow.maximumSize.width);
    final height = raw.height.clamp(minimumWindowSize.height, BrandDesktopWindow.maximumSize.height);
    final ratio = width / height;
    if ((ratio - BrandDesktopWindow.aspectRatio).abs() > .16) return defaultWindowSize;
    return Size(width, height);
  }

  Future<void> show({bool focus = true}) async {
    await windowManager.show();
    if (focus) await windowManager.focus();
    if (Platform.isMacOS) {
      await windowManager.setSkipTaskbar(false);
    }
  }

  Future<void> hide() async {
    await windowManager.hide();
    if (Platform.isMacOS) {
      await windowManager.setSkipTaskbar(true);
    }
  }

  Future<void> showOrHide() async {
    if (await windowManager.isVisible()) {
      await hide();
    } else {
      await show();
    }
  }

  Future<void> exit() async {
    await ref
        .read(connectionNotifierProvider.notifier)
        .shutdownForExit()
        .timeout(const Duration(seconds: 10))
        .catchError((e) {
          loggy.warning("error stopping connection on quit", e);
        });
    await trayManager.destroy();
    await windowManager.destroy();
  }
}
