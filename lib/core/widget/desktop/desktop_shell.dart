import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/widget/desktop/desktop_widgets.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:window_manager/window_manager.dart';

class DesktopShell extends HookConsumerWidget {
  const DesktopShell({super.key, required this.navigationShell, required this.actions});

  final StatefulNavigationShell navigationShell;
  final List<Object> actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DesktopTheme(
      child: Material(
        color: BrandDesktopColors.background,
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: BrandDesktopWindow.contentMaxWidth),
                child: Padding(padding: const EdgeInsets.only(top: 30), child: navigationShell),
              ),
            ),
            const Positioned(left: 0, top: 0, right: 42, height: 30, child: DragToMoveArea(child: SizedBox.expand())),
            const Positioned(top: 3, right: 5, child: _DesktopCloseButton()),
          ],
        ),
      ),
    );
  }
}

class _DesktopCloseButton extends StatelessWidget {
  const _DesktopCloseButton();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '关闭',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: windowManager.close,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BrandDesktopColors.card.withOpacity(.96),
              border: Border.all(color: BrandDesktopColors.border.withOpacity(.90)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 10, offset: const Offset(0, 3))],
            ),
            child: const Icon(Icons.close_rounded, size: 16, color: BrandDesktopColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
