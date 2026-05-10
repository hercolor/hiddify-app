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
  });

  static const height = 16.0;

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
            right: 0,
            height: height,
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
        ],
      ),
    );
  }
}
