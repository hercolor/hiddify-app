import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/features/auth/data/xboard_response_parser.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/utils/custom_loggers.dart';

abstract interface class LoginService {
  TaskEither<AuthFailure, AuthSession> login({required String email, required String password});
}

class XBoardLoginService with InfraLogger implements LoginService {
  XBoardLoginService({required DioHttpClient httpClient, required String apiBaseUrl})
    : _httpClient = httpClient,
      _apiBaseUrl = apiBaseUrl;

  final DioHttpClient _httpClient;
  final String _apiBaseUrl;

  @override
  TaskEither<AuthFailure, AuthSession> login({required String email, required String password}) {
    return TaskEither.tryCatch(
      () async {
        final response = await _httpClient.post<Map<String, dynamic>>(
          '$_apiBaseUrl/api/v1/passport/auth/login',
          data: {'email': email.trim(), 'password': password},
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        );

        if ((response.statusCode ?? 0) >= 400 || response.data == null) {
          throw const AuthFailure.badResponse('登录接口返回异常');
        }

        final authData = XBoardResponseParser.parseAuthData(response.data);
        final subscribeToken = XBoardResponseParser.parseSubscribeToken(response.data);
        return AuthSession(
          authData: authData,
          email: email.trim(),
          createdAt: DateTime.now(),
          subscribeToken: subscribeToken,
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
}
