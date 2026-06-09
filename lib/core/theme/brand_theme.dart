import 'package:flutter/material.dart';

abstract final class BrandColors {
  static const porcelain = Color(0xFFFFFFFF);
  static const mist = Color(0xFFF5F8FC);
  static const mistBlue = Color(0xFFEAF4FF);
  static const card = Color(0xFFFFFFFF);
  static const cardBlue = Color(0xFFF5F7FA);
  static const signalBlue = Color(0xFF007AFF);
  static const iceCyan = Color(0xFF38BDF8);
  static const deepSignal = Color(0xFF1238B7);
  static const slate = Color(0xFF111827);
  static const muted = Color(0xFF6B7280);
  static const subtle = Color(0xFFB0BEC5);
  static const border = Color(0xFFE7EEF7);
  static const success = Color(0xFF34C759);
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
    BoxShadow(color: BrandColors.signalBlue.withOpacity(.08), blurRadius: 28, offset: const Offset(0, 12)),
    BoxShadow(color: Colors.white.withOpacity(.85), blurRadius: 1, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> glow(Color color, {double alpha = .22}) => [
    BoxShadow(color: color.withOpacity(alpha), blurRadius: 36, spreadRadius: 2),
    BoxShadow(color: color.withOpacity(alpha / 2), blurRadius: 72, spreadRadius: 8),
  ];
}

abstract final class BrandDesktopColors {
  static const background = BrandColors.porcelain;
  static const panel = BrandColors.card;
  static const panelAlt = BrandColors.mist;
  static const card = Color(0xF7FFFFFF);
  static const cardSolid = BrandColors.card;
  static const cardElevated = BrandColors.cardBlue;
  static const input = BrandColors.card;
  static const border = BrandColors.border;
  static const borderStrong = Color(0x667AA2FF);
  static const textPrimary = BrandColors.slate;
  static const textSecondary = BrandColors.muted;
  static const textMuted = BrandColors.subtle;
  static const accent = BrandColors.signalBlue;
  static const cyan = BrandColors.iceCyan;
  static const indigo = BrandColors.deepSignal;
  static const success = BrandColors.success;
  static const warning = Color(0xFFF59E0B);
  static const error = BrandColors.error;
}

abstract final class BrandDesktopRadii {
  static const control = 16.0;
  static const card = 24.0;
  static const hero = 32.0;
}

abstract final class BrandDesktopWindow {
  static const defaultSize = Size(390, 910);
  static const minimumSize = defaultSize;
  static const maximumSize = defaultSize;
  static const aspectRatio = 3 / 7;
  static const contentMaxWidth = 390.0;
  static const bottomNavHeight = 78.0;
}

abstract final class BrandDesktopGradients {
  static const background = LinearGradient(
    colors: [BrandColors.porcelain, BrandColors.mist, Color(0xFFEFF7FF)],
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
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F8FC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

abstract final class BrandDesktopShadows {
  static List<BoxShadow> card = [
    BoxShadow(color: BrandDesktopColors.accent.withOpacity(.08), blurRadius: 28, offset: const Offset(0, 12)),
    BoxShadow(color: Colors.white.withOpacity(.9), blurRadius: 1, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> glow(Color color, {double alpha = .22}) => [
    BoxShadow(color: color.withOpacity(alpha), blurRadius: 34, spreadRadius: 1),
    BoxShadow(color: color.withOpacity(alpha / 2), blurRadius: 72, spreadRadius: 6),
  ];
}

abstract final class BrandText {
  static const brandTitle = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    color: BrandColors.signalBlue,
    letterSpacing: 2,
  );

  static const pageTitle = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: BrandColors.slate);

  static const sectionTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: BrandColors.slate);

  static const bodyPrimary = TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: BrandColors.slate);

  static const bodySecondary = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: BrandColors.muted);

  static const caption = TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: BrandColors.muted);

  static const label = TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: BrandColors.muted);

  static const buttonLabel = TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white);

  static const smallButton = TextStyle(fontSize: 13, fontWeight: FontWeight.w800);
}

abstract final class BrandDesktopText {
  static const pageTitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: BrandDesktopColors.textPrimary,
    letterSpacing: 0.2,
  );

  static const sectionTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: BrandDesktopColors.textPrimary,
  );

  static const bodyPrimary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: BrandDesktopColors.textPrimary,
  );

  static const bodySecondary = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: BrandDesktopColors.textSecondary,
  );

  static const caption = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BrandDesktopColors.textMuted);

  static const heroStatus = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: BrandDesktopColors.textPrimary,
    letterSpacing: 0.3,
  );

  static const cardValue = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: BrandDesktopColors.textPrimary,
    letterSpacing: -0.3,
  );

  static const cardLabel = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: BrandDesktopColors.textMuted);

  static const buttonLabel = TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white);

  static const smallButton = TextStyle(fontSize: 12, fontWeight: FontWeight.w700);
}

abstract final class BrandDesktopButtons {
  static ButtonStyle primary({double height = 44}) => ElevatedButton.styleFrom(
    backgroundColor: BrandDesktopColors.accent,
    foregroundColor: Colors.white,
    minimumSize: Size(double.infinity, height),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BrandDesktopRadii.control)),
    elevation: 0,
    textStyle: BrandDesktopText.buttonLabel,
  );

  static ButtonStyle secondary({double height = 44}) => OutlinedButton.styleFrom(
    foregroundColor: BrandDesktopColors.accent,
    minimumSize: Size(double.infinity, height),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BrandDesktopRadii.control)),
    side: const BorderSide(color: BrandDesktopColors.accent),
    textStyle: BrandDesktopText.buttonLabel.copyWith(color: BrandDesktopColors.accent),
  );

  static ButtonStyle small() => ElevatedButton.styleFrom(
    backgroundColor: Colors.white.withOpacity(.10),
    foregroundColor: const Color(0xFFFFD700),
    minimumSize: const Size(52, 32),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.white.withOpacity(.12)),
    ),
    elevation: 0,
    textStyle: BrandDesktopText.smallButton,
  );

  static ButtonStyle danger({double height = 44}) => TextButton.styleFrom(
    foregroundColor: BrandDesktopColors.error,
    backgroundColor: BrandDesktopColors.error.withOpacity(.10),
    minimumSize: Size(double.infinity, height),
    padding: const EdgeInsets.symmetric(vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BrandDesktopRadii.control)),
    textStyle: BrandDesktopText.buttonLabel.copyWith(color: BrandDesktopColors.error),
  );
}
