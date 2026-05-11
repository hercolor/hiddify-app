import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowChrome extends StatelessWidget {
  const DesktopWindowChrome({
    super.key,
    required this.child,
    this.backgroundColor = BrandDesktopColors.background,
    this.reserveTop = false,
    this.showCloseButton = true,
  });

  static const height = 16.0;

  final Widget child;
  final Color backgroundColor;
  final bool reserveTop;
  final bool showCloseButton;

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
            right: 0,
            height: height,
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
          if (showCloseButton) const Positioned(top: 2, right: 2, child: _DesktopWindowCloseButton()),
        ],
      ),
    );
  }
}

class _DesktopWindowCloseButton extends StatefulWidget {
  const _DesktopWindowCloseButton();

  @override
  State<_DesktopWindowCloseButton> createState() => _DesktopWindowCloseButtonState();
}

class _DesktopWindowCloseButtonState extends State<_DesktopWindowCloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final background = _hovered ? const Color(0xFFFEE2E2) : Colors.white.withOpacity(.76);
    final foreground = _hovered ? BrandDesktopColors.error : BrandDesktopColors.textMuted;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: '关闭',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: windowManager.close,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: _hovered ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(color: const Color(0xFF0F172A).withOpacity(.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(Icons.close_rounded, size: 12, color: foreground),
          ),
        ),
      ),
    );
  }
}
