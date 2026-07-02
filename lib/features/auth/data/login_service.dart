import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/auth/data/xboard_response_parser.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/utils/custom_loggers.dart';

final _fallbackAuthText = AppLocale.en.buildSync();
Translations get _authText => _fallbackAuthText;

abstract interface class LoginService {
  TaskEither<AuthFailure, AuthSession> login({required String account, required String password});

  TaskEither<AuthFailure, AuthSession> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  });

  TaskEither<AuthFailure, Unit> sendEmailVerify({required String account});

  TaskEither<AuthFailure, Unit> sendPhoneVerify({required String account});

  TaskEither<AuthFailure, Unit> resetPassword({
    required String account,
    required String verifyCode,
    required String password,
  });

  TaskEither<AuthFailure, Unit> changePassword({
    required String authData,
    required String oldPassword,
    required String newPassword,
  });

  TaskEither<AuthFailure, String?> fetchBoundPhone({required String authData});

  TaskEither<AuthFailure, Unit> sendPhoneBindVerify({required String authData, required String phone});

  TaskEither<AuthFailure, String> bindPhone({
    required String authData,
    required String phone,
    required String phoneCode,
  });
}

class XBoardLoginService with InfraLogger implements LoginService {
  XBoardLoginService({required DioHttpClient httpClient, required String apiBaseUrl})
    : _httpClient = httpClient,
      _apiBaseUrl = apiBaseUrl;

  final DioHttpClient _httpClient;
  final String _apiBaseUrl;

  @override
  TaskEither<AuthFailure, AuthSession> login({required String account, required String password}) {
    return TaskEither.tryCatch(
      () async {
        // Debug 模式下使用模拟登录
        if (kDebugMode) {
          return AuthSession(
            authData: 'Bearer mock_test_token_12345',
            email: account.trim(),
            createdAt: DateTime.now(),
            subscribeToken: 'mock_subscribe_token',
            subscription: UserSubscription(
              subscribeUrl: 'https://mock.api.y88.pro/api/v1/client/subscribe?token=mock_token',
              expiredAt: DateTime.now().add(const Duration(days: 365)),
              upload: 0,
              download: 0,
              transferEnable: 1099511627776, // 1TB
              planId: 1,
              planName: '测试年卡',
              membershipStatus: 'year',
              membershipLabel: '蝴蝶年卡',
              subscriptionStatus: 'normal',
              serverCanConnect: true,
              maxDevices: 5,
            ),
          );
        }

        final trimmedAccount = account.trim();
        final response = await _httpClient.post<Map<String, dynamic>>(
          '$_apiBaseUrl/api/v1/passport/auth/login',
          data: _loginPayload(account: trimmedAccount, password: password),
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        );
        return _sessionFromResponse(
          response,
          account: trimmedAccount,
          fallbackMessage: _authText.errors.auth.loginBadResponse,
        );
      },
      (error, stackTrace) {
        if (error is AuthFailure) return error;
        if (error is DioException) {
          final failure = authFailureFromDioException(error, treatUnauthorizedAsExpired: false);
          loggy.warning('login request failed', failure);
          return failure;
        }
        loggy.warning('login failed', error, stackTrace);
        return AuthFailure.unexpected(error, stackTrace);
      },
    );
  }

  @override
  TaskEither<AuthFailure, AuthSession> register({
    required String email,
    required String password,
    String? emailCode,
    String? inviteCode,
  }) {
    return TaskEither.tryCatch(() async {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/passport/auth/register',
        data: {
          'email': email.trim(),
          'password': password,
          if (emailCode != null && emailCode.trim().isNotEmpty) 'email_code': emailCode.trim(),
          if (inviteCode != null && inviteCode.trim().isNotEmpty) 'invite_code': inviteCode.trim(),
        },
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      );
      return _sessionFromResponse(
        response,
        account: email.trim(),
        fallbackMessage: _authText.errors.auth.registerBadResponse,
      );
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'register request failed'));
  }

  @override
  TaskEither<AuthFailure, Unit> sendEmailVerify({required String account}) {
    return TaskEither.tryCatch(() async {
      final trimmedAccount = account.trim();
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/passport/comm/sendEmailVerify',
        data: _accountPayload(trimmedAccount),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      );
      _ensureOk(response, fallbackMessage: _authText.errors.auth.emailVerifyFailed);
      return unit;
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'send email verify failed'));
  }

  @override
  TaskEither<AuthFailure, Unit> sendPhoneVerify({required String account}) {
    return TaskEither.tryCatch(() async {
      final trimmedAccount = account.trim();
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/passport/comm/sendPhoneVerify',
        data: _accountPayload(trimmedAccount),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      );
      _ensureOk(response, fallbackMessage: _authText.errors.auth.phoneVerifyFailed);
      return unit;
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'send phone verify failed'));
  }

  @override
  TaskEither<AuthFailure, Unit> resetPassword({
    required String account,
    required String verifyCode,
    required String password,
  }) {
    return TaskEither.tryCatch(() async {
      final trimmedAccount = account.trim();
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/passport/auth/forget',
        data: {
          ..._accountPayload(trimmedAccount),
          if (trimmedAccount.contains('@')) 'email_code': verifyCode.trim() else 'phone_code': verifyCode.trim(),
          'password': password,
        },
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      );
      _ensureOk(response, fallbackMessage: _authText.errors.auth.resetPasswordFailed);
      return unit;
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'reset password failed'));
  }

  @override
  TaskEither<AuthFailure, Unit> changePassword({
    required String authData,
    required String oldPassword,
    required String newPassword,
  }) {
    return TaskEither.tryCatch(() async {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/changePassword',
        data: {'old_password': oldPassword, 'new_password': newPassword},
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': authData},
      );
      _ensureOk(response, fallbackMessage: _authText.errors.auth.changePasswordFailed);
      return unit;
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'change password failed'));
  }

  @override
  TaskEither<AuthFailure, String?> fetchBoundPhone({required String authData}) {
    return TaskEither.tryCatch(() async {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/info',
        headers: {'Accept': 'application/json', 'Authorization': authData},
      );
      _ensureOk(response, fallbackMessage: _authText.errors.auth.userInfoBadResponse);
      return XBoardResponseParser.parsePhone(response.data);
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'fetch bound phone failed'));
  }

  @override
  TaskEither<AuthFailure, Unit> sendPhoneBindVerify({required String authData, required String phone}) {
    return TaskEither.tryCatch(() async {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/phone/sendVerify',
        data: {'phone': phone.trim()},
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': authData},
      );
      _ensureOk(response, fallbackMessage: _authText.errors.auth.phoneVerifyFailed);
      return unit;
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'send bind phone verify failed'));
  }

  @override
  TaskEither<AuthFailure, String> bindPhone({
    required String authData,
    required String phone,
    required String phoneCode,
  }) {
    return TaskEither.tryCatch(() async {
      final normalizedPhone = phone.trim();
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/phone/bind',
        data: {'phone': normalizedPhone, 'phone_code': phoneCode.trim()},
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': authData},
      );
      _ensureOk(response, fallbackMessage: _authText.errors.auth.bindPhoneFailed);
      return XBoardResponseParser.parsePhone(response.data) ?? normalizedPhone;
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'bind phone failed'));
  }

  Map<String, String> _loginPayload({required String account, required String password}) {
    if (account.contains('@')) {
      return {'account': account, 'email': account, 'password': password};
    }
    return {'account': account, 'password': password};
  }

  Map<String, String> _accountPayload(String account) {
    if (account.contains('@')) {
      return {'account': account, 'email': account};
    }
    return {'account': account};
  }

  AuthSession _sessionFromResponse(
    Response<Map<String, dynamic>> response, {
    required String account,
    required String fallbackMessage,
  }) {
    _ensureOk(response, fallbackMessage: fallbackMessage);
    final authData = XBoardResponseParser.parseAuthData(response.data);
    final subscribeToken = XBoardResponseParser.parseSubscribeToken(response.data);
    final subscribeUrl = XBoardResponseParser.parseSubscribeUrl(response.data, baseUrl: _apiBaseUrl);
    return AuthSession(
      authData: authData,
      email: XBoardResponseParser.parseEmail(response.data) ?? account.trim(),
      phone: XBoardResponseParser.parsePhone(response.data),
      createdAt: DateTime.now(),
      subscribeToken: subscribeToken,
      subscription: subscribeUrl == null ? null : UserSubscription(subscribeUrl: subscribeUrl),
    );
  }

  void _ensureOk(Response<Map<String, dynamic>> response, {required String fallbackMessage}) {
    if ((response.statusCode ?? 0) >= 400 || response.data == null) {
      throw AuthFailure.badResponse(fallbackMessage);
    }
    final data = response.data!;
    final status = data['status']?.toString().toLowerCase();
    if (status == 'fail') {
      throw AuthFailure.serverMessage(_stringValue(data['message']) ?? fallbackMessage);
    }
  }

  AuthFailure _toAuthFailure(Object error, StackTrace stackTrace, {required String action}) {
    if (error is AuthFailure) return error;
    if (error is DioException) {
      final failure = authFailureFromDioException(error, treatUnauthorizedAsExpired: false);
      loggy.warning(action, failure);
      return failure;
    }
    loggy.warning(action, error, stackTrace);
    return AuthFailure.unexpected(error, stackTrace);
  }

  String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
