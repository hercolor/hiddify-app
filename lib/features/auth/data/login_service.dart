import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/features/auth/data/xboard_response_parser.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/utils/custom_loggers.dart';

abstract interface class LoginService {
  TaskEither<AuthFailure, AuthSession> login({required String account, required String password});

  TaskEither<AuthFailure, AuthSession> register({
    required String email,
    String? phone,
    required String password,
    String? emailCode,
    String? inviteCode,
  });

  TaskEither<AuthFailure, Unit> sendEmailVerify({required String email});

  TaskEither<AuthFailure, Unit> resetPassword({
    required String email,
    required String emailCode,
    required String password,
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
        final trimmedAccount = account.trim();
        final response = await _httpClient.post<Map<String, dynamic>>(
          '$_apiBaseUrl/api/v1/passport/auth/login',
          data: _loginPayload(account: trimmedAccount, password: password),
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        );
        return _sessionFromResponse(response, account: trimmedAccount, fallbackMessage: '登录接口返回异常');
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
    String? phone,
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
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          if (emailCode != null && emailCode.trim().isNotEmpty) 'email_code': emailCode.trim(),
          if (inviteCode != null && inviteCode.trim().isNotEmpty) 'invite_code': inviteCode.trim(),
        },
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      );
      return _sessionFromResponse(response, account: email.trim(), fallbackMessage: '注册接口返回异常');
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'register request failed'));
  }

  @override
  TaskEither<AuthFailure, Unit> sendEmailVerify({required String email}) {
    return TaskEither.tryCatch(() async {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/passport/comm/sendEmailVerify',
        data: {'email': email.trim()},
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      );
      _ensureOk(response, fallbackMessage: '验证码发送失败');
      return unit;
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'send email verify failed'));
  }

  @override
  TaskEither<AuthFailure, Unit> resetPassword({
    required String email,
    required String emailCode,
    required String password,
  }) {
    return TaskEither.tryCatch(() async {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/passport/auth/forget',
        data: {'email': email.trim(), 'email_code': emailCode.trim(), 'password': password},
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      );
      _ensureOk(response, fallbackMessage: '密码重置失败');
      return unit;
    }, (error, stackTrace) => _toAuthFailure(error, stackTrace, action: 'reset password failed'));
  }

  Map<String, String> _loginPayload({required String account, required String password}) {
    if (account.contains('@')) {
      return {'account': account, 'email': account, 'password': password};
    }
    return {'account': account, 'password': password};
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
