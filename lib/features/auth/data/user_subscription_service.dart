import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/features/auth/data/xboard_response_parser.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';
import 'package:hiddify/utils/custom_loggers.dart';

abstract interface class UserSubscriptionService {
  TaskEither<AuthFailure, UserSubscription> fetchSubscription(
    String authData, {
    String? subscribeToken,
    String? fallbackSubscribeUrl,
  });
}

class XBoardUserSubscriptionService with InfraLogger implements UserSubscriptionService {
  XBoardUserSubscriptionService({required DioHttpClient httpClient, required String apiBaseUrl})
    : _httpClient = httpClient,
      _apiBaseUrl = apiBaseUrl;

  final DioHttpClient _httpClient;
  final String _apiBaseUrl;

  @override
  TaskEither<AuthFailure, UserSubscription> fetchSubscription(
    String authData, {
    String? subscribeToken,
    String? fallbackSubscribeUrl,
  }) {
    return TaskEither.tryCatch(
      () async {
        _logAuthDataForFirstUserRequest(authData);
        final storedSubscribeUrl = fallbackSubscribeUrl?.trim();
        final fallbackUrl = storedSubscribeUrl == null || storedSubscribeUrl.isEmpty
            ? _subscribeUrlFromToken(subscribeToken)
            : storedSubscribeUrl;
        final response = await _httpClient.get<Map<String, dynamic>>(
          '$_apiBaseUrl/api/v1/user/getSubscribe',
          headers: {'Accept': 'application/json', 'Authorization': authData},
        );

        if ((response.statusCode ?? 0) >= 400 || response.data == null) {
          throw const AuthFailure.badResponse('订阅接口返回异常');
        }

        loggy.debug('subscription response keys: ${_sanitizedKeys(response.data).join(',')}');
        final subscription = XBoardResponseParser.parseSubscription(
          response.data,
          fallbackSubscribeUrl: fallbackUrl,
          baseUrl: _apiBaseUrl,
        );
        _logSubscribeUrlSummary(subscription.subscribeUrl);
        final customerService = subscription.customerService ?? await _fetchCustomerService(authData);
        return customerService == null ? subscription : subscription.copyWith(customerService: customerService);
      },
      (error, stackTrace) {
        if (error is AuthFailure) return error;
        if (error is DioException) {
          final failure = authFailureFromDioException(error);
          loggy.warning('subscription request failed', failure);
          return failure;
        }
        loggy.warning('subscription fetch failed', error, stackTrace);
        return AuthFailure.unexpected(error, stackTrace);
      },
    );
  }

  String? _subscribeUrlFromToken(String? subscribeToken) {
    final token = subscribeToken?.trim();
    if (token == null || token.isEmpty) return null;
    return Uri.parse(
      _apiBaseUrl,
    ).resolve('/api/v1/client/subscribe?token=${Uri.encodeQueryComponent(token)}&flag=hiddify').toString();
  }

  void _logSubscribeUrlSummary(String subscribeUrl) {
    final uri = Uri.tryParse(subscribeUrl);
    loggy.debug(
      'subscription url summary: '
      'exists=${subscribeUrl.trim().isNotEmpty}, '
      'absolute=${uri?.hasScheme == true}, '
      'path=${_safePath(uri?.path)}, '
      'hasToken=${uri?.queryParameters.keys.any((key) => key.toLowerCase() == 'token') == true}, '
      'hasFlag=${uri?.queryParameters.keys.any((key) => key.toLowerCase() == 'flag') == true}, '
      'length=${subscribeUrl.length}',
    );
  }

  String _safePath(String? path) {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) return '--';
    if (trimmed.length > 80) return '${trimmed.substring(0, 80)}…';
    return trimmed;
  }

  Future<String?> _fetchCustomerService(String authData) async {
    for (final path in const ['/api/v1/guest/comm/config', '/api/v1/passport/comm/config']) {
      try {
        final response = await _httpClient.get<Map<String, dynamic>>(
          '$_apiBaseUrl$path',
          headers: {'Accept': 'application/json', 'Authorization': authData},
        );
        if ((response.statusCode ?? 0) >= 400 || response.data == null) continue;
        loggy.debug('customer service response keys: ${_sanitizedKeys(response.data).join(',')}');
        final value = XBoardResponseParser.parseCustomerService(response.data);
        if (value != null && value.trim().isNotEmpty) return value.trim();
      } catch (error, stackTrace) {
        loggy.debug('customer service config request skipped', error, stackTrace);
      }
    }
    return null;
  }

  void _logAuthDataForFirstUserRequest(String authData) {
    final trimmed = authData.trim();
    loggy.debug(
      'first user info request authData: '
      'exists=${trimmed.isNotEmpty}, '
      'length=${trimmed.length}, '
      'startsWithBearer=${trimmed.toLowerCase().startsWith('bearer ')}',
    );
  }

  List<String> _sanitizedKeys(Object? value, {String prefix = '', int depth = 0}) {
    if (depth > 2 || value is! Map) return const [];
    final keys = <String>[];
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final path = prefix.isEmpty ? key : '$prefix.$key';
      keys.add(path);
      if (entry.value is Map) {
        keys.addAll(_sanitizedKeys(entry.value, prefix: path, depth: depth + 1));
      }
    }
    return keys.take(80).toList(growable: false);
  }
}
