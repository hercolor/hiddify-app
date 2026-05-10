import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hiddify/core/widget/desktop/desktop_window_chrome.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key, required this.navigationShell, required this.actions});

  final StatefulNavigationShell navigationShell;
  final List<Object> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DesktopTheme(
      child: Material(
        color: BrandDesktopColors.background,
        child: DesktopWindowChrome(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: BrandDesktopWindow.contentMaxWidth),
              child: navigationShell,
            ),
          ),
        ),
      ),
    );
  }
}
