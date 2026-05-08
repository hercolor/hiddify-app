import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiddify/core/theme/app_theme_mode.dart';
import 'package:hiddify/core/theme/brand_theme.dart';
import 'package:hiddify/core/theme/theme_extensions.dart';

class AppTheme {
  AppTheme(this.mode, this.fontFamily);
  final AppThemeMode mode;
  final String fontFamily;
  static const Color _brandSeedColor = BrandColors.signalBlue;

  ThemeData lightTheme(ColorScheme? lightColorScheme) {
    const ColorScheme scheme = ColorScheme.light(
      primary: BrandColors.signalBlue,
      secondary: BrandColors.iceCyan,
      onSecondary: BrandColors.slate,
      tertiary: BrandColors.success,
      error: BrandColors.error,
      onSurface: BrandColors.slate,
      surfaceContainer: BrandColors.mist,
      surfaceContainerHighest: BrandColors.cardBlue,
      onSurfaceVariant: BrandColors.muted,
      outline: BrandColors.border,
      outlineVariant: BrandColors.border,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: BrandColors.mist,
      fontFamily: fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: BrandColors.porcelain,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: BrandColors.slate,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -.2,
        ),
        iconTheme: IconThemeData(color: BrandColors.slate),
      ),
      cardTheme: CardThemeData(
        color: BrandColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: BrandColors.signalBlue.withOpacity(.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BrandRadii.lg)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BrandRadii.md)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandColors.signalBlue,
          side: const BorderSide(color: BrandColors.border),
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(BrandRadii.md)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: BrandColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandRadii.md),
          borderSide: const BorderSide(color: BrandColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandRadii.md),
          borderSide: const BorderSide(color: BrandColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandRadii.md),
          borderSide: const BorderSide(color: BrandColors.signalBlue, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(BrandRadii.md),
          borderSide: const BorderSide(color: BrandColors.error),
        ),
        labelStyle: const TextStyle(color: BrandColors.muted, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: BrandColors.subtle),
        prefixIconColor: BrandColors.signalBlue,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: BrandColors.card.withOpacity(.96),
        indicatorColor: BrandColors.mistBlue,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected) ? BrandColors.signalBlue : BrandColors.muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? BrandColors.signalBlue : BrandColors.subtle,
            size: 24,
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: BrandColors.slate, fontWeight: FontWeight.w800, letterSpacing: -.8),
        headlineMedium: TextStyle(color: BrandColors.slate, fontWeight: FontWeight.w800, letterSpacing: -.5),
        headlineSmall: TextStyle(color: BrandColors.slate, fontWeight: FontWeight.w800, letterSpacing: -.3),
        titleLarge: TextStyle(color: BrandColors.slate, fontWeight: FontWeight.w800),
        titleMedium: TextStyle(color: BrandColors.slate, fontWeight: FontWeight.w700),
        titleSmall: TextStyle(color: BrandColors.slate, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(color: BrandColors.slate, fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(color: BrandColors.muted),
        bodySmall: TextStyle(color: BrandColors.muted),
        labelLarge: TextStyle(fontWeight: FontWeight.w700),
        labelMedium: TextStyle(color: BrandColors.muted, fontWeight: FontWeight.w600),
      ),
      dividerTheme: const DividerThemeData(color: BrandColors.border, thickness: 1, space: 1),
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  ThemeData darkTheme(ColorScheme? darkColorScheme) {
    final ColorScheme scheme =
        darkColorScheme ?? ColorScheme.fromSeed(seedColor: _brandSeedColor, brightness: Brightness.dark);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: mode.trueBlack ? Colors.black : scheme.surface,
      fontFamily: fontFamily,
      extensions: const <ThemeExtension<dynamic>>{ConnectionButtonTheme.light},
    );
  }

  CupertinoThemeData cupertinoThemeData(bool sysDark, ColorScheme? lightColorScheme, ColorScheme? darkColorScheme) {
    final bool isDark = switch (mode) {
      AppThemeMode.system => sysDark,
      AppThemeMode.light => false,
      AppThemeMode.dark => true,
      AppThemeMode.black => true,
    };
    final def = CupertinoThemeData(brightness: isDark ? Brightness.dark : Brightness.light);
    // final def = CupertinoThemeData(brightness: Brightness.dark);

    // return def;
    final defaultMaterialTheme = isDark ? darkTheme(darkColorScheme) : lightTheme(lightColorScheme);
    return MaterialBasedCupertinoThemeData(
      materialTheme: defaultMaterialTheme.copyWith(
        cupertinoOverrideTheme: def.copyWith(
          textTheme: CupertinoTextThemeData(
            textStyle: def.textTheme.textStyle.copyWith(fontFamily: fontFamily),
            actionTextStyle: def.textTheme.actionTextStyle.copyWith(fontFamily: fontFamily),
            navActionTextStyle: def.textTheme.navActionTextStyle.copyWith(fontFamily: fontFamily),
            navTitleTextStyle: def.textTheme.navTitleTextStyle.copyWith(fontFamily: fontFamily),
            navLargeTitleTextStyle: def.textTheme.navLargeTitleTextStyle.copyWith(fontFamily: fontFamily),
            pickerTextStyle: def.textTheme.pickerTextStyle.copyWith(fontFamily: fontFamily),
            dateTimePickerTextStyle: def.textTheme.dateTimePickerTextStyle.copyWith(fontFamily: fontFamily),
            tabLabelTextStyle: def.textTheme.tabLabelTextStyle.copyWith(fontFamily: fontFamily),
          ).copyWith(),
          barBackgroundColor: def.barBackgroundColor,
          scaffoldBackgroundColor: def.scaffoldBackgroundColor,
        ),
      ),
    );
  }
}
