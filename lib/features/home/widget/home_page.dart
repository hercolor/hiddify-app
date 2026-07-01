import 'package:flutter/material.dart';
import 'package:hiddify/features/home/widget/desktop_home_page.dart';
import 'package:hiddify/features/home/widget/mobile_home_page.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (PlatformUtils.isWindows) {
      return const DesktopHomePage();
    }
    return const MobileHomePage();
  }
}
