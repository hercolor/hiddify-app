import 'dart:io';

import 'package:flutter/foundation.dart';

abstract class PlatformUtils {
  static bool get isWindows => false; // TEMP: force mobile layout for Android UI preview
  static bool get isDesktop => false; // TEMP: force mobile layout for Android UI preview

  static bool get isInAppStore => !kIsWeb && (Platform.isIOS);

  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get isWeb => kIsWeb;

  static bool get isLinux => !kIsWeb && Platform.isLinux;

  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
}
