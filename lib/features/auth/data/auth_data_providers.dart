import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/data/app_config.dart';
import 'package:hiddify/features/auth/data/auth_token_storage.dart';
import 'package:hiddify/features/auth/data/login_service.dart';
import 'package:hiddify/features/auth/data/user_subscription_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_data_providers.g.dart';

@Riverpod(keepAlive: true)
Future<AppConfig> appConfig(Ref ref) async {
  final raw = await rootBundle.loadString('assets/config/app_config.json');
  return AppConfig.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
}

@Riverpod(keepAlive: true)
FlutterSecureStorage flutterSecureStorage(Ref ref) {
  return const FlutterSecureStorage(aOptions: AndroidOptions(preferencesKeyPrefix: 'hiddify_xboard_'));
}

@Riverpod(keepAlive: true)
AuthTokenStorage authTokenStorage(Ref ref) {
  return SecureAuthTokenStorage(ref.watch(flutterSecureStorageProvider));
}

@Riverpod(keepAlive: true)
Future<LoginService> loginService(Ref ref) async {
  final config = await ref.watch(appConfigProvider.future);
  return XBoardLoginService(httpClient: ref.watch(httpClientProvider), apiBaseUrl: config.xboardApiBaseUrl);
}

@Riverpod(keepAlive: true)
Future<UserSubscriptionService> userSubscriptionService(Ref ref) async {
  final config = await ref.watch(appConfigProvider.future);
  return XBoardUserSubscriptionService(httpClient: ref.watch(httpClientProvider), apiBaseUrl: config.xboardApiBaseUrl);
}
