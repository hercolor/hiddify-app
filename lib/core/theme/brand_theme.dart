import 'package:flutter/material.dart';

/// BflyVPN 设计系统 v1 的唯一颜色来源。见 `docs/bflyvpn-design-system-v1.md` §2。
///
/// 中性色采用 slate 体系（与既有页面里用量最大的一套一致），品牌色为靛紫→青。
/// **新代码不得再写字面量颜色。**
abstract final class BrandPalette {
  // 中性色
  static const ink = Color(0xFF0F172A);
  static const inkMuted = Color(0xFF64748B);
  static const inkFaint = Color(0xFF94A3B8);
  static const line = Color(0xFFE2E8F0);
  static const wash = Color(0xFFF1F5F9);
  static const canvas = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);

  // 品牌色
  static const brand = Color(0xFF4F46E5);
  static const brandDeep = Color(0xFF3730A3);

  /// 白底对比度仅 1.81:1 —— **只能做渐变端点或大面积图形填充，
  /// 禁止用作文字与需要辨识的图标颜色**（设计系统 §2.2）。
  static const brandGlow = Color(0xFF22D3EE);

  // 语义色
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);

  /// 危险色浅底：警示区块与销毁类按钮的填充，不用于文字。
  static const dangerWash = Color(0xFFFEF2F2);
  static const dangerWashHover = Color(0xFFFEE2E2);

  // 会员：浅色界面里唯一的深色锚点，与主渐变区分开
  static const vipCardTop = Color(0xFF2A2D3E);
  static const vip = Color(0xFFFFD700);
  static const vipDeep = Color(0xFFFFA000);

  /// 金色徽标上的文字色，金底对比度 7.4:1。
  static const vipInk = Color(0xFF5C4000);
}

abstract final class BrandColors {
  static const porcelain = BrandPalette.surface;
  static const mist = BrandPalette.canvas;
  static const mistBlue = Color(0xFFEEF2FF);
  static const card = BrandPalette.surface;
  static const cardBlue = BrandPalette.wash;
  static const signalBlue = BrandPalette.brand;
  static const iceCyan = BrandPalette.brandGlow;
  static const deepSignal = BrandPalette.brandDeep;
  static const slate = BrandPalette.ink;
  static const muted = BrandPalette.inkMuted;
  static const subtle = BrandPalette.inkFaint;
  static const border = BrandPalette.line;
  static const success = BrandPalette.success;
  static const warning = BrandPalette.warning;
  static const error = BrandPalette.danger;
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
