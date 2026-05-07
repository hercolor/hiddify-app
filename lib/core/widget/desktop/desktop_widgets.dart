import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/theme/brand_theme.dart';

class DesktopTheme extends StatelessWidget {
  const DesktopTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final textTheme = base.textTheme.apply(
      bodyColor: BrandDesktopColors.textPrimary,
      displayColor: BrandDesktopColors.textPrimary,
    );
    return Theme(
      data: base.copyWith(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BrandDesktopColors.background,
        colorScheme: const ColorScheme.dark(
          primary: BrandDesktopColors.accent,
          secondary: BrandDesktopColors.cyan,
          surface: BrandDesktopColors.panel,
          error: BrandDesktopColors.error,
          onSurface: BrandDesktopColors.textPrimary,
          onSurfaceVariant: BrandDesktopColors.textSecondary,
          outline: BrandDesktopColors.border,
        ),
        textTheme: textTheme.copyWith(
          headlineLarge: textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1),
          headlineMedium: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -.8),
          headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -.4),
          titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          titleSmall: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          bodyMedium: textTheme.bodyMedium?.copyWith(color: BrandDesktopColors.textSecondary),
          bodySmall: textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textMuted),
          labelLarge: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
          labelMedium: textTheme.labelMedium?.copyWith(
            color: BrandDesktopColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          foregroundColor: BrandDesktopColors.textPrimary,
          titleTextStyle: TextStyle(color: BrandDesktopColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
          iconTheme: IconThemeData(color: BrandDesktopColors.textPrimary),
        ),
        dividerTheme: DividerThemeData(color: BrandDesktopColors.border.withValues(alpha: .72), thickness: 1, space: 1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: BrandDesktopColors.input,
          prefixIconColor: BrandDesktopColors.textMuted,
          suffixIconColor: BrandDesktopColors.textMuted,
          labelStyle: const TextStyle(color: BrandDesktopColors.textSecondary, fontWeight: FontWeight.w600),
          hintStyle: const TextStyle(color: BrandDesktopColors.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BrandDesktopRadii.control),
            borderSide: const BorderSide(color: BrandDesktopColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BrandDesktopRadii.control),
            borderSide: const BorderSide(color: BrandDesktopColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BrandDesktopRadii.control),
            borderSide: const BorderSide(color: BrandDesktopColors.accent, width: 1.2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(BrandDesktopRadii.control),
            borderSide: const BorderSide(color: BrandDesktopColors.error),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(84, 48),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BrandDesktopRadii.control)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      child: child,
    );
  }
}

class DesktopBackdrop extends StatelessWidget {
  const DesktopBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: BrandDesktopGradients.background),
      child: Stack(
        children: [
          const Positioned(
            top: -180,
            left: -120,
            child: _DesktopGlow(size: 360, color: BrandDesktopColors.accent, alpha: .20),
          ),
          const Positioned(
            top: 120,
            right: -140,
            child: _DesktopGlow(size: 420, color: BrandDesktopColors.cyan, alpha: .12),
          ),
          const Positioned(
            bottom: -220,
            left: 220,
            child: _DesktopGlow(size: 520, color: BrandDesktopColors.indigo, alpha: .13),
          ),
          Positioned.fill(
            child: IgnorePointer(child: CustomPaint(painter: _GridPainter())),
          ),
          child,
        ],
      ),
    );
  }
}

class DesktopPageScaffold extends StatelessWidget {
  const DesktopPageScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    required this.child,
    this.padding,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DesktopTheme(
      child: DesktopBackdrop(
        child: SafeArea(
          child: Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 14,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.headlineSmall?.copyWith(color: BrandDesktopColors.textPrimary),
                        ),
                        if (subtitle != null) ...[
                          const Gap(6),
                          Text(
                            subtitle!,
                            style: theme.textTheme.bodyMedium?.copyWith(color: BrandDesktopColors.textSecondary),
                          ),
                        ],
                      ],
                    ),
                    if (actions != null && actions!.isNotEmpty) Wrap(spacing: 10, runSpacing: 10, children: actions!),
                  ],
                ),
                const Gap(16),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DesktopCard extends StatelessWidget {
  const DesktopCard({super.key, required this.child, this.padding, this.gradient, this.borderColor, this.onTap});

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Gradient? gradient;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(BrandDesktopRadii.card),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: padding ?? const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: gradient == null ? BrandDesktopColors.card : null,
            gradient: gradient,
            borderRadius: BorderRadius.circular(BrandDesktopRadii.card),
            border: Border.all(color: borderColor ?? BrandDesktopColors.border),
            boxShadow: BrandDesktopShadows.card,
          ),
          child: child,
        ),
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(borderRadius: BorderRadius.circular(BrandDesktopRadii.card), onTap: onTap, child: content),
    );
  }
}

class DesktopIconBox extends StatelessWidget {
  const DesktopIconBox({super.key, required this.icon, this.selected = false, this.size = 42, this.color});

  final IconData icon;
  final bool selected;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? (selected ? BrandDesktopColors.accent : BrandDesktopColors.textSecondary);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: selected ? BrandDesktopGradients.primary : null,
        color: selected ? null : BrandDesktopColors.cardElevated,
        borderRadius: BorderRadius.circular(size * .34),
        border: Border.all(color: selected ? Colors.white.withValues(alpha: .10) : BrandDesktopColors.border),
        boxShadow: selected ? BrandDesktopShadows.glow(BrandDesktopColors.accent, alpha: .20) : null,
      ),
      child: Icon(icon, color: selected ? Colors.white : resolved, size: size * .48),
    );
  }
}

class DesktopStatusPill extends StatelessWidget {
  const DesktopStatusPill({super.key, required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.circle, size: icon == null ? 8 : 15, color: color),
          const Gap(7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class DesktopMetricTile extends StatelessWidget {
  const DesktopMetricTile({super.key, required this.icon, required this.label, required this.value, this.accent});

  final IconData icon;
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accent ?? BrandDesktopColors.accent;
    return DesktopCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          DesktopIconBox(icon: icon, color: color),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.bodySmall?.copyWith(color: BrandDesktopColors.textMuted)),
                const Gap(5),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: BrandDesktopColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DesktopGradientButton extends StatelessWidget {
  const DesktopGradientButton({super.key, required this.label, this.icon, this.onPressed, this.isLoading = false});

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : BrandDesktopGradients.primary,
        color: onPressed == null ? BrandDesktopColors.cardElevated : null,
        borderRadius: BorderRadius.circular(BrandDesktopRadii.control),
        boxShadow: onPressed == null ? null : BrandDesktopShadows.glow(BrandDesktopColors.accent, alpha: .16),
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: isLoading
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon ?? Icons.arrow_forward_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
      ),
    );
  }
}

class _DesktopGlow extends StatelessWidget {
  const _DesktopGlow({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: alpha * .22),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: .025)
      ..strokeWidth = 1;
    const step = 48.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
