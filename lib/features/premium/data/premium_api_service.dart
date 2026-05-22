import 'package:dio/dio.dart';
import 'package:hiddify/core/http_client/dio_http_client.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final premiumApiServiceProvider = FutureProvider<PremiumApiService>((ref) async {
  final config = await ref.watch(appConfigProvider.future);
  return XBoardPremiumApiService(httpClient: ref.watch(httpClientProvider), apiBaseUrl: config.xboardApiBaseUrl);
});

abstract interface class PremiumApiService {
  Future<PremiumInviteOverview> fetchInvite(String authData);

  Future<void> createInviteCode(String authData);

  Future<PremiumCommissionPage> fetchCommissionDetails(String authData, {int current = 1, int pageSize = 10});

  Future<void> createTicket(String authData, {required String subject, required int level, required String message});

  Future<List<PremiumTicketSummary>> fetchTickets(String authData);
}

class XBoardPremiumApiService with InfraLogger implements PremiumApiService {
  XBoardPremiumApiService({required DioHttpClient httpClient, required String apiBaseUrl})
    : _httpClient = httpClient,
      _apiBaseUrl = apiBaseUrl;

  final DioHttpClient _httpClient;
  final String _apiBaseUrl;

  @override
  Future<PremiumInviteOverview> fetchInvite(String authData) async {
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/invite/fetch',
        headers: _jsonHeaders(authData),
      );
      _ensureOk(response.statusCode, response.data, fallbackMessage: '邀请接口返回异常');
      return PremiumInviteOverview.fromJson(response.data);
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'invite fetch failed');
    }
  }

  @override
  Future<void> createInviteCode(String authData) async {
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/invite/save',
        headers: _jsonHeaders(authData),
      );
      _ensureOk(response.statusCode, response.data, fallbackMessage: '邀请码生成失败');
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'invite code create failed');
    }
  }

  @override
  Future<PremiumCommissionPage> fetchCommissionDetails(String authData, {int current = 1, int pageSize = 10}) async {
    try {
      final uri = Uri.parse(
        '$_apiBaseUrl/api/v1/user/invite/details',
      ).replace(queryParameters: {'current': '$current', 'page_size': '$pageSize'});
      final response = await _httpClient.get<Map<String, dynamic>>(uri.toString(), headers: _jsonHeaders(authData));
      _ensureOk(response.statusCode, response.data, fallbackMessage: '佣金记录返回异常', allowRawPayload: true);
      return PremiumCommissionPage.fromJson(response.data);
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'commission details fetch failed');
    }
  }

  @override
  Future<void> createTicket(
    String authData, {
    required String subject,
    required int level,
    required String message,
  }) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/ticket/save',
        data: {'subject': subject.trim(), 'level': level, 'message': message.trim()},
        headers: _jsonHeaders(authData),
      );
      _ensureOk(response.statusCode, response.data, fallbackMessage: '工单提交失败');
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'ticket create failed');
    }
  }

  @override
  Future<List<PremiumTicketSummary>> fetchTickets(String authData) async {
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '$_apiBaseUrl/api/v1/user/ticket/fetch',
        headers: _jsonHeaders(authData),
      );
      _ensureOk(response.statusCode, response.data, fallbackMessage: '工单列表返回异常');
      return PremiumTicketSummary.listFromResponse(response.data);
    } catch (error, stackTrace) {
      throw _toAuthFailure(error, stackTrace, action: 'ticket fetch failed');
    }
  }

  Map<String, String> _jsonHeaders(String authData) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': authData,
  };

  void _ensureOk(
    int? statusCode,
    Map<String, dynamic>? data, {
    required String fallbackMessage,
    bool allowRawPayload = false,
  }) {
    if ((statusCode ?? 0) >= 400 || data == null) {
      throw AuthFailure.badResponse(fallbackMessage);
    }
    final status = data['status']?.toString().toLowerCase();
    if (status == 'fail') {
      throw AuthFailure.serverMessage(_stringValue(data['message']) ?? fallbackMessage);
    }
    if (!allowRawPayload && status != null && status != 'success') {
      throw AuthFailure.badResponse(_stringValue(data['message']) ?? fallbackMessage);
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

class PremiumInviteOverview {
  const PremiumInviteOverview({required this.codes, required this.stat});

  final List<PremiumInviteCode> codes;
  final PremiumInviteStat stat;

  factory PremiumInviteOverview.fromJson(Object? responseData) {
    final payload = _payload(responseData);
    final codesValue = _valueByKey(payload, 'codes');
    return PremiumInviteOverview(
      codes: _listPayload(codesValue).map(PremiumInviteCode.fromJson).where((code) => code.code.isNotEmpty).toList(),
      stat: PremiumInviteStat.fromJson(_valueByKey(payload, 'stat')),
    );
  }
}

class PremiumInviteCode {
  const PremiumInviteCode({required this.code, this.pv, this.status, this.createdAt});

  final String code;
  final int? pv;
  final int? status;
  final DateTime? createdAt;

  factory PremiumInviteCode.fromJson(Object? data) {
    final map = data is Map ? data : const <String, dynamic>{};
    return PremiumInviteCode(
      code: _stringValue(_valueByKey(map, 'code'))?.trim() ?? '',
      pv: _intValue(_valueByKey(map, 'pv')),
      status: _intValue(_valueByKey(map, 'status')),
      createdAt: _dateTimeValue(_valueByKey(map, 'created_at')) ?? _dateTimeValue(_valueByKey(map, 'createdAt')),
    );
  }
}

class PremiumInviteStat {
  const PremiumInviteStat({
    required this.registeredUserCount,
    required this.validCommissionAmountCents,
    required this.pendingCommissionAmountCents,
    required this.commissionRatePercent,
    required this.availableCommissionBalanceCents,
  });

  final int registeredUserCount;
  final int validCommissionAmountCents;
  final int pendingCommissionAmountCents;
  final int commissionRatePercent;
  final int availableCommissionBalanceCents;

  factory PremiumInviteStat.fromJson(Object? data) {
    if (data is List) {
      return PremiumInviteStat(
        registeredUserCount: _intAt(data, 0),
        validCommissionAmountCents: _intAt(data, 1),
        pendingCommissionAmountCents: _intAt(data, 2),
        commissionRatePercent: _intAt(data, 3),
        availableCommissionBalanceCents: _intAt(data, 4),
      );
    }
    final map = data is Map ? data : const <String, dynamic>{};
    return PremiumInviteStat(
      registeredUserCount: _intByKeys(map, const ['registered_user_count', 'registeredUserCount', 'registered']) ?? 0,
      validCommissionAmountCents:
          _intByKeys(map, const ['valid_commission_amount_cents', 'validCommissionAmountCents', 'valid']) ?? 0,
      pendingCommissionAmountCents:
          _intByKeys(map, const ['pending_commission_amount_cents', 'pendingCommissionAmountCents', 'pending']) ?? 0,
      commissionRatePercent: _intByKeys(map, const ['commission_rate_percent', 'commissionRatePercent', 'rate']) ?? 0,
      availableCommissionBalanceCents:
          _intByKeys(map, const [
            'available_commission_balance_cents',
            'availableCommissionBalanceCents',
            'available',
          ]) ??
          0,
    );
  }
}

class PremiumCommissionPage {
  const PremiumCommissionPage({required this.records, required this.total});

  final List<PremiumCommissionLog> records;
  final int total;

  factory PremiumCommissionPage.fromJson(Object? responseData) {
    final payload = _payload(responseData, unwrapData: false);
    final records = _listPayload(_valueByKey(payload, 'data'));
    return PremiumCommissionPage(
      records: records.map(PremiumCommissionLog.fromJson).toList(),
      total: _intValue(_valueByKey(payload, 'total')) ?? records.length,
    );
  }
}

class PremiumCommissionLog {
  const PremiumCommissionLog({required this.amountCents, this.orderAmountCents, this.tradeNo, this.createdAt});

  final int amountCents;
  final int? orderAmountCents;
  final String? tradeNo;
  final DateTime? createdAt;

  factory PremiumCommissionLog.fromJson(Object? data) {
    final map = data is Map ? data : const <String, dynamic>{};
    return PremiumCommissionLog(
      amountCents: _intByKeys(map, const ['get_amount', 'getAmount', 'amount']) ?? 0,
      orderAmountCents: _intByKeys(map, const ['order_amount', 'orderAmount']),
      tradeNo: _stringValue(_valueByKey(map, 'trade_no')) ?? _stringValue(_valueByKey(map, 'tradeNo')),
      createdAt: _dateTimeValue(_valueByKey(map, 'created_at')) ?? _dateTimeValue(_valueByKey(map, 'createdAt')),
    );
  }
}

class PremiumTicketSummary {
  const PremiumTicketSummary({
    required this.id,
    required this.subject,
    required this.status,
    this.replyStatus,
    this.createdAt,
  });

  final int id;
  final String subject;
  final int status;
  final int? replyStatus;
  final DateTime? createdAt;

  bool get isClosed => status != 0;

  factory PremiumTicketSummary.fromJson(Object? data) {
    final map = data is Map ? data : const <String, dynamic>{};
    return PremiumTicketSummary(
      id: _intValue(_valueByKey(map, 'id')) ?? 0,
      subject: _stringValue(_valueByKey(map, 'subject'))?.trim() ?? '问题反馈',
      status: _intValue(_valueByKey(map, 'status')) ?? 0,
      replyStatus: _intValue(_valueByKey(map, 'reply_status')) ?? _intValue(_valueByKey(map, 'replyStatus')),
      createdAt: _dateTimeValue(_valueByKey(map, 'created_at')) ?? _dateTimeValue(_valueByKey(map, 'createdAt')),
    );
  }

  static List<PremiumTicketSummary> listFromResponse(Object? responseData) {
    final payload = _payload(responseData);
    return _listPayload(payload).map(PremiumTicketSummary.fromJson).where((ticket) => ticket.id > 0).toList();
  }
}

Object? _payload(Object? responseData, {bool unwrapData = true}) {
  if (responseData is Map && unwrapData && responseData.containsKey('data')) return responseData['data'];
  return responseData;
}

List<Object?> _listPayload(Object? data) {
  if (data is List) return data;
  if (data is Map && data['data'] is List) return data['data'] as List;
  return const [];
}

Object? _valueByKey(Object? value, String key) {
  if (value is! Map) return null;
  for (final entry in value.entries) {
    if (entry.key.toString().toLowerCase() == key.toLowerCase()) return entry.value;
  }
  return null;
}

int? _intByKeys(Map<dynamic, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = _valueByKey(map, key);
    final parsed = _intValue(value);
    if (parsed != null) return parsed;
  }
  return null;
}

int _intAt(List<dynamic> values, int index) => index >= values.length ? 0 : _intValue(values[index]) ?? 0;

int? _intValue(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String? _stringValue(Object? value) {
  if (value == null) return null;
  if (value is Map || value is Iterable) return null;
  return value.toString();
}

DateTime? _dateTimeValue(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is num) {
    final raw = value.toInt();
    if (raw <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(raw > 9999999999 ? raw : raw * 1000);
  }
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final asInt = int.tryParse(text);
  if (asInt != null) {
    if (asInt <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(asInt > 9999999999 ? asInt : asInt * 1000);
  }
  return DateTime.tryParse(text);
}
