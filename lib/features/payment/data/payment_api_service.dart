import 'package:dio/dio.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/payment/model/payment_models.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final paymentApiServiceProvider = FutureProvider<PaymentApiService>((ref) async {
  final config = await ref.watch(appConfigProvider.future);
  return XBoardPaymentApiService(httpClient: ref.watch(httpClientProvider), apiBaseUrl: config.xboardApiBaseUrl);
});

abstract interface class PaymentApiService {
  /// 创建订单，返回订单号。
  Future<String> createOrder(String authData, {required int planId, required String period});

  /// 结账：拿到系统浏览器打开的支付地址；余额直付时可能无需跳转。
  Future<PaymentCheckout> checkout(String authData, {required String tradeNo, int? methodId});

  /// 查单：**订单状态的唯一权威来源**。
  Future<PaymentOrder> fetchOrder(String authData, {required String tradeNo});

  /// 可用支付方式。付费订单没有可用方式时必须显式失败。
  Future<List<PaymentMethod>> fetchPaymentMethods(String authData);
}

class PaymentMethod {
  const PaymentMethod({required this.id, required this.name});

  final int id;
  final String name;
}

class XBoardPaymentApiService with InfraLogger implements PaymentApiService {
  XBoardPaymentApiService({required DioHttpClient httpClient, required String apiBaseUrl})
    : _httpClient = httpClient,
      _apiBaseUrl = apiBaseUrl;

  final DioHttpClient _httpClient;
  final String _apiBaseUrl;

  @override
  Future<String> createOrder(String authData, {required int planId, required String period}) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/order/save',
        data: {'plan_id': planId, 'period': period},
        headers: _jsonHeaders(authData),
      );
      _ensureOk(response.statusCode, response.data, fallbackMessage: '创建订单失败');
      final tradeNo = _stringValue(_unwrap(response.data))?.trim();
      if (tradeNo == null || tradeNo.isEmpty) {
        throw const AuthFailure.badResponse('创建订单失败');
      }
      return tradeNo;
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'order create failed');
    }
  }

  @override
  Future<PaymentCheckout> checkout(String authData, {required String tradeNo, int? methodId}) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/order/checkout',
        data: {'trade_no': tradeNo, if (methodId != null) 'method': methodId},
        headers: _jsonHeaders(authData),
      );
      _ensureOk(response.statusCode, response.data, fallbackMessage: '发起支付失败');
      final payload = _unwrap(response.data);
      // 后端可能返回 true（余额已抵扣，无需跳转）或支付地址字符串。
      if (payload is bool) {
        return PaymentCheckout(tradeNo: tradeNo, settledWithoutRedirect: payload);
      }
      final payUrl = _stringValue(payload)?.trim() ?? _stringValue(_valueByKey(payload, 'url'))?.trim();
      if (payUrl == null || payUrl.isEmpty) {
        throw const AuthFailure.badResponse('发起支付失败');
      }
      final payUri = Uri.tryParse(payUrl);
      if (payUri == null || payUri.scheme.toLowerCase() != 'https' || payUri.host.isEmpty) {
        // 规范 §5.4：pay_url 仅允许 HTTPS。
        throw const AuthFailure.badResponse('支付地址不安全，已阻止打开');
      }
      return PaymentCheckout(tradeNo: tradeNo, payUrl: payUri.toString());
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'order checkout failed');
    }
  }

  @override
  Future<PaymentOrder> fetchOrder(String authData, {required String tradeNo}) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/api/v1/user/order/detail').replace(queryParameters: {'trade_no': tradeNo});
      final response = await _httpClient.get<Map<String, dynamic>>(uri.toString(), headers: _jsonHeaders(authData));
      _ensureOk(response.statusCode, response.data, fallbackMessage: '查询订单失败');
      final payload = _unwrap(response.data);
      return PaymentOrder(
        tradeNo: _stringValue(_valueByKey(payload, 'trade_no'))?.trim().isNotEmpty == true
            ? _stringValue(_valueByKey(payload, 'trade_no'))!.trim()
            : tradeNo,
        status: PaymentOrderStatus.fromCode(_intValue(_valueByKey(payload, 'status'))),
        planId: _intValue(_valueByKey(payload, 'plan_id')),
        totalAmountCents: _intValue(_valueByKey(payload, 'total_amount')),
      );
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'order detail failed');
    }
  }

  @override
  Future<List<PaymentMethod>> fetchPaymentMethods(String authData) async {
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/order/getPaymentMethod',
        headers: _jsonHeaders(authData),
      );
      _ensureOk(response.statusCode, response.data, fallbackMessage: '支付方式返回异常');
      final payload = _unwrap(response.data);
      if (payload is! List) {
        throw const AuthFailure.badResponse('支付方式返回异常');
      }
      final methods = payload
          .map((item) {
            final id = _intValue(_valueByKey(item, 'id'));
            final name = _stringValue(_valueByKey(item, 'name'))?.trim();
            if (id == null) return null;
            return PaymentMethod(id: id, name: name?.isNotEmpty == true ? name! : '在线支付');
          })
          .whereType<PaymentMethod>()
          .toList();
      if (methods.isEmpty) {
        throw const AuthFailure.badResponse('暂无可用支付方式');
      }
      return methods;
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'payment method fetch failed');
    }
  }

  Map<String, String> _jsonHeaders(String authData) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': authData,
  };

  void _ensureOk(int? statusCode, Map<String, dynamic>? data, {required String fallbackMessage}) {
    if ((statusCode ?? 0) >= 400 || data == null) {
      throw AuthFailure.badResponse(fallbackMessage);
    }
    final status = data['status']?.toString().toLowerCase();
    if (status == 'fail') {
      throw AuthFailure.serverMessage(_stringValue(data['message']) ?? fallbackMessage);
    }
  }

  AuthFailure _toAuthFailure(Object error, StackTrace stackTrace, {required String action}) {
    if (error is AuthFailure) return error;
    if (error is DioException) {
      final failure = authFailureFromDioException(error);
      loggy.warning(action, failure);
      return failure;
    }
    loggy.warning(action, error, stackTrace);
    return AuthFailure.unexpected(error, stackTrace);
  }
}

Object? _unwrap(Object? responseData) {
  if (responseData is Map && responseData.containsKey('data')) return responseData['data'];
  return responseData;
}

Object? _valueByKey(Object? value, String key) {
  if (value is! Map) return null;
  for (final entry in value.entries) {
    if (entry.key.toString().toLowerCase() == key.toLowerCase()) return entry.value;
  }
  return null;
}

int? _intValue(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value.toString().trim();
  return int.tryParse(text) ?? double.tryParse(text)?.round();
}

String? _stringValue(Object? value) {
  if (value == null) return null;
  if (value is Map || value is Iterable || value is bool) return null;
  return value.toString();
}
