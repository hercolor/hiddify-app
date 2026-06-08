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
      AuthInvalidCredentialsFailure(:final message) => (type: '账号或密码不正确', message: message),
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
  final message = _extractMessage(error.response?.data);
  if (statusCode == 400 && _isInvalidCredentialMessage(message)) {
    return const AuthFailure.invalidCredentials();
  }
  if (treatUnauthorizedAsExpired && statusCode == 401) {
    return const AuthFailure.tokenExpired();
  }
  if (treatUnauthorizedAsExpired && statusCode == 403) {
    if (_isSubscriptionUnavailableMessage(message)) {
      return AuthFailure.serverMessage(_localizedServerMessage(message) ?? '会员已到期，请续费后再使用');
    }
    return AuthFailure.tokenExpired(message);
  }
  if (statusCode == 422) {
    if (_isInvalidCredentialMessage(message)) {
      return AuthFailure.invalidCredentials(_localizedServerMessage(message) ?? message);
    }
    return AuthFailure.serverMessage(_localizedServerMessage(message) ?? message ?? '请求参数不正确');
  }
  if (statusCode != null && statusCode >= 400) {
    return AuthFailure.badResponse(_localizedServerMessage(message) ?? message ?? 'HTTP $statusCode');
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
    for (final key in ['errors', 'data']) {
      final nested = _extractMessage(data[key]);
      if (nested != null && nested.trim().isNotEmpty) return nested;
    }
    for (final value in data.values) {
      if (value is! Map && value is! Iterable) continue;
      final nested = _extractMessage(value);
      if (nested != null && nested.trim().isNotEmpty) return nested;
    }
  }
  if (data is Iterable) {
    for (final value in data) {
      final nested = _extractMessage(value);
      if (nested != null && nested.trim().isNotEmpty) return nested;
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
  }
  final text = data?.toString().trim();
  if (text != null && text.isNotEmpty && text != 'null') {
    return text;
  }
  return null;
}

bool _isInvalidCredentialMessage(String? message) {
  final normalized = message?.toLowerCase().trim();
  if (normalized == null || normalized.isEmpty) return false;
  return normalized.contains('incorrect account or password') ||
      normalized.contains('invalid account or password') ||
      normalized.contains('账号或密码');
}

bool _isSubscriptionUnavailableMessage(String? message) {
  final normalized = message?.toLowerCase().trim();
  if (normalized == null || normalized.isEmpty) return false;
  return normalized.contains('expired') ||
      normalized.contains('unavailable') ||
      normalized.contains('subscription') ||
      normalized.contains('到期') ||
      normalized.contains('过期') ||
      normalized.contains('流量');
}

String? _localizedServerMessage(String? message) {
  final normalized = message?.toLowerCase().trim();
  if (normalized == null || normalized.isEmpty) return null;
  if (_isInvalidCredentialMessage(normalized)) return '账号或密码不正确';
  if (normalized.contains('email already exists')) return '邮箱已被注册';
  if (normalized.contains('phone already exists')) return '手机号已被绑定';
  if (normalized.contains('incorrect email verification code')) return '邮箱验证码不正确';
  if (normalized.contains('incorrect phone verification code')) return '手机验证码不正确';
  if (normalized.contains('the old password is wrong')) return '原密码不正确';
  if (normalized.contains('old password cannot be empty')) return '请输入原密码';
  if (normalized.contains('new password cannot be empty')) return '请输入新密码';
  if (normalized.contains('this phone is not registered')) return '该手机号未绑定账号';
  if (normalized.contains('this email is not registered')) return '该邮箱未注册';
  if (normalized.contains('phone format is incorrect')) return '手机号格式不正确';
  if (normalized.contains('email format is incorrect')) return '邮箱格式不正确';
  if (_isSubscriptionUnavailableMessage(normalized)) return '会员已到期或流量不足，请续费后再使用';
  return null;
}
