import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowChrome extends StatelessWidget {
  const DesktopWindowChrome({
    super.key,
    required this.child,
    this.backgroundColor = BrandDesktopColors.background,
    this.reserveTop = true,
  });

  static const height = 34.0;

  final Widget child;
  final Color backgroundColor;
  final bool reserveTop;

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isWindows) return child;
    return Material(
      color: backgroundColor,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: reserveTop ? height : 0),
            child: child,
          ),
          const Positioned(
            left: 0,
            top: 0,
            right: 42,
            height: height,
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
          const Positioned(top: 4, right: 6, child: DesktopWindowCloseButton()),
        ],
      ),
    );
  }
}

class DesktopWindowCloseButton extends StatelessWidget {
  const DesktopWindowCloseButton({super.key});

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
