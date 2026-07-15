import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/theme/brand_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40, this.showWordmark = true, this.dark = false, this.wordmarkStyle});

  final double size;
  final bool showWordmark;
  final bool dark;
  final TextStyle? wordmarkStyle;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BrandRouteMarkPainter(dark: dark)),
    );
    if (!showWordmark) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * .28),
        Text(
          'BflyVPN',
          style:
              wordmarkStyle ??
              Theme.of(context).textTheme.titleLarge?.copyWith(
                color: dark ? Colors.white : BrandColors.slate,
                fontWeight: FontWeight.w800,
                letterSpacing: -.6,
              ),
        ),
      ],
    );
  }
}

class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, this.size = 44, this.selected = false, this.icon});

  final double size;
  final bool selected;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: selected ? BrandGradients.primary : null,
        color: selected ? null : BrandColors.cardBlue,
        borderRadius: BorderRadius.circular(size * .35),
        border: Border.all(color: selected ? Colors.transparent : BrandColors.border),
        boxShadow: selected ? BrandShadows.glow(BrandColors.signalBlue, alpha: .16) : null,
      ),
      child: icon == null
          ? Padding(
              padding: EdgeInsets.all(size * .23),
              child: CustomPaint(painter: _BrandRouteMarkPainter(dark: selected)),
            )
          : Icon(icon, size: size * .48, color: selected ? Colors.white : BrandColors.signalBlue),
    );
  }
}

class BrandScaffoldBackground extends StatelessWidget {
  const BrandScaffoldBackground({super.key, required this.child, this.showHalos = true});

  final Widget child;
  final bool showHalos;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: BrandColors.porcelain,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: BrandColors.mist),
        child: child,
      ),
    );
  }
}

class _BrandRouteMarkPainter extends CustomPainter {
  const _BrandRouteMarkPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final strokeWidth = size.width * .12;
    final path = Path()
      ..moveTo(size.width * .20, size.height * .62)
      ..cubicTo(
        size.width * .34,
        size.height * .18,
        size.width * .78,
        size.height * .18,
        size.width * .82,
        size.height * .47,
      )
      ..cubicTo(
        size.width * .88,
        size.height * .86,
        size.width * .30,
        size.height * .86,
        size.width * .26,
        size.height * .45,
      );

    final paint = Paint()
      ..shader = BrandGradients.primary.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    final innerPaint = Paint()
      ..color = (dark ? Colors.white : BrandColors.signalBlue).withOpacity(.95)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * .71, size.height * .37), size.width * .105, innerPaint);
    canvas.drawCircle(
      Offset(size.width * .32, size.height * .66),
      size.width * .065,
      innerPaint..color = BrandColors.iceCyan,
    );
  }

  @override
  bool shouldRepaint(covariant _BrandRouteMarkPainter oldDelegate) => oldDelegate.dark != dark;
}
