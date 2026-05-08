import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:hiddify/bootstrap.dart';
import 'package:hiddify/core/model/environment.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // final widgetsBinding = SentryWidgetsFlutterBinding.ensureInitialized();
  // debugPaintSizeEnabled = true;

  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.setTitle('4376');
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: BrandColors.porcelain,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  return await lazyBootstrap(widgetsBinding, Environment.dev);
}
