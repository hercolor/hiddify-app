import 'package:dio/dio.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';

part 'auth_failure.freezed.dart';

@freezed
sealed class AuthFailure with _$AuthFailure, Failure {
  const AuthFailure._();

  @With<UnexpectedFailure>()
  const factory AuthFailure.unexpected([Object? error, StackTrace? stackTrace]) = AuthUnexpectedFailure;

  @With<ExpectedFailure>()
  const factory AuthFailure.invalidCredentials([String? message]) = AuthInvalidCredentialsFailure;

  @With<ExpectedFailure>()
  const factory AuthFailure.tokenExpired([String? message]) = AuthTokenExpiredFailure;

  @With<ExpectedFailure>()
  const factory AuthFailure.notLoggedIn() = AuthNotLoggedInFailure;

  @With<ExpectedFailure>()
  const factory AuthFailure.network([String? message]) = AuthNetworkFailure;

  @With<ExpectedFailure>()
  const factory AuthFailure.badResponse([String? message]) = AuthBadResponseFailure;

  @With<ExpectedFailure>()
  const factory AuthFailure.serverMessage(String message) = AuthServerMessageFailure;

  @override
  ({String type, String? message}) present(TranslationsEn t) {
    return switch (this) {
      AuthUnexpectedFailure() => (type: '发生未知错误', message: null),
      AuthInvalidCredentialsFailure(:final message) => (type: '邮箱或密码不正确', message: message),
      AuthTokenExpiredFailure(:final message) => (type: '登录已过期，请重新登录', message: message),
      AuthNotLoggedInFailure() => (type: '请先登录', message: null),
      AuthNetworkFailure(:final message) => (type: '网络连接失败，请稍后重试', message: message),
      AuthBadResponseFailure(:final message) => (type: '服务器返回异常', message: message),
      AuthServerMessageFailure(:final message) => (type: message, message: null),
    };
  }
}

AuthFailure authFailureFromDioException(DioException error, {bool treatUnauthorizedAsExpired = true}) {
  final statusCode = error.response?.statusCode;
  if (treatUnauthorizedAsExpired && (statusCode == 401 || statusCode == 403)) {
    return const AuthFailure.tokenExpired();
  }
  if (statusCode == 422) {
    return AuthFailure.invalidCredentials(_extractMessage(error.response?.data));
  }
  if (statusCode != null && statusCode >= 400) {
    return AuthFailure.badResponse(_extractMessage(error.response?.data) ?? 'HTTP $statusCode');
  }
  return AuthFailure.network(error.message);
}

String? _extractMessage(Object? data) {
  if (data is Map) {
    for (final key in ['message', 'msg', 'error']) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
  }
  return null;
}
