import 'package:flutter/widgets.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/gen/translations.g.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'locale_preferences.g.dart';

@Riverpod(keepAlive: true)
class LocalePreferences extends _$LocalePreferences with AppLogger {
  @override
  AppLocale build() {
    final persisted = ref.watch(sharedPreferencesProvider).requireValue.getString("locale");
    if (persisted == null) return _findSystemLocaleOrZhCn();
    // keep backward compatibility with chinese after changing zh to zh_CN
    if (persisted == "zh") {
      return AppLocale.zhCn;
    }
    try {
      return AppLocale.values.byName(persisted);
    } catch (e) {
      loggy.error("error setting locale: [$persisted]", e);
      return AppLocale.zhCn;
    }
  }

  Future<void> changeLocale(AppLocale value) async {
    state = value;
    await ref.read(sharedPreferencesProvider).requireValue.setString("locale", value.name);
  }

  AppLocale _findSystemLocaleOrZhCn() {
    try {
      final locales = WidgetsBinding.instance.platformDispatcher.locales;
      for (final locale in locales) {
        final exact = AppLocale.values.where(
          (appLocale) =>
              appLocale.languageCode == locale.languageCode &&
              (appLocale.countryCode == null || appLocale.countryCode == locale.countryCode),
        );
        if (exact.isNotEmpty) return exact.first;
      }
      for (final locale in locales) {
        final languageMatch = AppLocale.values.where((appLocale) => appLocale.languageCode == locale.languageCode);
        if (languageMatch.isNotEmpty) return languageMatch.first;
      }
    } catch (e) {
      loggy.error("error detecting system locale", e);
    }
    return AppLocale.zhCn;
  }
}
