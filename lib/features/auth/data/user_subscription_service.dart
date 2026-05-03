import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/features/auth/data/xboard_response_parser.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/utils/custom_loggers.dart';

abstract interface class UserSubscriptionService {
  TaskEither<AuthFailure, UserSubscription> fetchSubscription(String token);
}

class XBoardUserSubscriptionService with InfraLogger implements UserSubscriptionService {
  XBoardUserSubscriptionService({required DioHttpClient httpClient, required String apiBaseUrl})
    : _httpClient = httpClient,
      _apiBaseUrl = apiBaseUrl;

  final DioHttpClient _httpClient;
  final String _apiBaseUrl;

  @override
  TaskEither<AuthFailure, UserSubscription> fetchSubscription(String token) {
    return TaskEither.tryCatch(
      () async {
        final response = await _httpClient.get<Map<String, dynamic>>(
          '$_apiBaseUrl/api/v1/user/getSubscribe',
          headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        );

        if ((response.statusCode ?? 0) >= 400 || response.data == null) {
          throw const AuthFailure.badResponse('订阅接口返回异常');
        }

        return XBoardResponseParser.parseSubscription(response.data);
      },
      (error, stackTrace) {
        if (error is AuthFailure) return error;
        if (error is DioException) {
          final failure = authFailureFromDioException(error);
          loggy.warning('xboard subscription request failed', failure);
          return failure;
        }
        loggy.warning('xboard subscription fetch failed', error, stackTrace);
        return AuthFailure.unexpected(error, stackTrace);
      },
    );
  }
}
