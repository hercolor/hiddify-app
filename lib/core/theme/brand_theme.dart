import 'package:flutter/material.dart';

abstract final class BrandColors {
  static const porcelain = Color(0xFFFFFFFF);
  static const mist = Color(0xFFF5F8FC);
  static const mistBlue = Color(0xFFEAF2FF);
  static const card = Color(0xFFFFFFFF);
  static const cardBlue = Color(0xFFF8FBFF);
  static const signalBlue = Color(0xFF2563FF);
  static const iceCyan = Color(0xFF38BDF8);
  static const deepSignal = Color(0xFF1238B7);
  static const slate = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const subtle = Color(0xFF94A3B8);
  static const border = Color(0xFFE4ECF7);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const dark = Color(0xFF07111F);
}

abstract final class BrandRadii {
  static const xs = 10.0;
  static const sm = 14.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class BrandSpacing {
  static const page = 20.0;
  static const card = 18.0;
}

abstract final class BrandGradients {
  static const primary = LinearGradient(
    colors: [BrandColors.signalBlue, BrandColors.iceCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const connected = LinearGradient(
    colors: [BrandColors.success, BrandColors.iceCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const softBackground = LinearGradient(
    colors: [BrandColors.porcelain, BrandColors.mist, Color(0xFFEFF7FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

abstract final class BrandShadows {
  static List<BoxShadow> card = [
    BoxShadow(color: BrandColors.signalBlue.withValues(alpha: .08), blurRadius: 28, offset: const Offset(0, 12)),
    BoxShadow(color: Colors.white.withValues(alpha: .85), blurRadius: 1, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> glow(Color color, {double alpha = .22}) => [
    BoxShadow(color: color.withValues(alpha: alpha), blurRadius: 36, spreadRadius: 2),
    BoxShadow(color: color.withValues(alpha: alpha / 2), blurRadius: 72, spreadRadius: 8),
  ];
}

abstract final class BrandDesktopColors {
  static const background = Color(0xFF070B14);
  static const panel = Color(0xFF0C1220);
  static const panelAlt = Color(0xFF0F172A);
  static const card = Color(0xCC111A2C);
  static const cardSolid = Color(0xFF111A2C);
  static const cardElevated = Color(0xFF162238);
  static const input = Color(0xFF0D1525);
  static const border = Color(0x2E94A3B8);
  static const borderStrong = Color(0x527AA2FF);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const accent = Color(0xFF4F8CFF);
  static const cyan = Color(0xFF22D3EE);
  static const indigo = Color(0xFF5B5CFF);
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
}

abstract final class BrandDesktopRadii {
  static const control = 16.0;
  static const card = 24.0;
  static const hero = 32.0;
}

abstract final class BrandDesktopWindow {
  static const defaultSize = Size(430, 760);
  static const minimumSize = Size(390, 690);
  static const maximumSize = Size(560, 980);
  static const aspectRatio = 4 / 7;
  static const contentMaxWidth = 520.0;
  static const bottomNavHeight = 82.0;
}

abstract final class BrandDesktopGradients {
  static const background = LinearGradient(
    colors: [BrandDesktopColors.background, Color(0xFF0A1020), Color(0xFF060914)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const primary = LinearGradient(
    colors: [BrandDesktopColors.accent, BrandDesktopColors.cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const connected = LinearGradient(
    colors: [BrandDesktopColors.success, BrandDesktopColors.cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const card = LinearGradient(
    colors: [Color(0xE6172338), Color(0xB50D1525)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class BrandDesktopShadows {
  static List<BoxShadow> card = [
    BoxShadow(color: Colors.black.withValues(alpha: .28), blurRadius: 30, offset: const Offset(0, 18)),
    BoxShadow(color: BrandDesktopColors.accent.withValues(alpha: .035), blurRadius: 42, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> glow(Color color, {double alpha = .22}) => [
    BoxShadow(color: color.withValues(alpha: alpha), blurRadius: 34, spreadRadius: 1),
    BoxShadow(color: color.withValues(alpha: alpha / 2), blurRadius: 72, spreadRadius: 6),
  ];
}
