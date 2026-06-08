import 'dart:convert';

import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';

class XBoardResponseParser {
  const XBoardResponseParser._();

  static String parseAuthData(Object? responseData) {
    final data = _decodeIfString(responseData);
    final authData = _findStringByKeys(data, const ['auth_data', 'authData', 'authorization']);
    if (authData == null || authData.trim().isEmpty) {
      throw const AuthFailure.badResponse('登录成功但未返回 auth_data');
    }
    return _normalizeBearer(authData.trim());
  }

  static String? parseSubscribeToken(Object? responseData) {
    final data = _decodeIfString(responseData);
    final token = _findStringByKeys(data, const ['token', 'subscribe_token', 'subscribeToken']);
    final trimmed = token?.trim();
    return trimmed == null || trimmed.isEmpty ? null : _stripBearer(trimmed);
  }

  static String? parseEmail(Object? responseData) {
    final data = _decodeIfString(responseData);
    final email = _findStringByKeys(data, const ['email', 'mail']);
    final trimmed = email?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? parsePhone(Object? responseData) {
    final data = _decodeIfString(responseData);
    final phone = _findStringByKeys(data, const ['phone', 'mobile']);
    final trimmed = phone?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? parseSubscribeUrl(Object? responseData, {String? fallbackSubscribeUrl, String? baseUrl}) {
    final data = _decodeIfString(responseData);
    final subscribeUrl = _resolveSubscribeUrl(_findSubscriptionUrl(data) ?? fallbackSubscribeUrl, baseUrl);
    final trimmed = subscribeUrl?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static UserSubscription parseSubscription(Object? responseData, {String? fallbackSubscribeUrl, String? baseUrl}) {
    final data = _decodeIfString(responseData);
    final subscribeUrl = parseSubscribeUrl(data, fallbackSubscribeUrl: fallbackSubscribeUrl, baseUrl: baseUrl);
    final serverCanConnect = _findBoolByKeys(data, const ['can_connect', 'canConnect']);
    if ((subscribeUrl == null || subscribeUrl.trim().isEmpty) && serverCanConnect != false) {
      throw const AuthFailure.serverMessage('订阅信息为空，请联系客服');
    }

    return UserSubscription(
      subscribeUrl: subscribeUrl?.trim() ?? '',
      expiredAt: _findDateTimeByKeys(data, const [
        'expired_at',
        'expiredAt',
        'expire',
        'expired',
        'expires_at',
        'expiresAt',
      ]),
      upload: _findIntByKeys(data, const ['u', 'upload', 'uploaded']) ?? 0,
      download: _findIntByKeys(data, const ['d', 'download', 'downloaded']) ?? 0,
      transferEnable:
          _findIntByKeys(data, const ['transfer_enable', 'transferEnable', 'transfer', 'total', 'traffic']) ?? 0,
      planId: _findIntByKeys(data, const ['plan_id', 'planId']),
      planName: _findPlanName(data),
      membershipStatus: _findStringByKeys(data, const ['membership_status', 'membershipStatus'])?.trim(),
      membershipLabel: _findStringByKeys(data, const ['membership_label', 'membershipLabel'])?.trim(),
      subscriptionStatus: _findStringByKeys(data, const ['subscription_status', 'subscriptionStatus'])?.trim(),
      serverCanConnect: serverCanConnect,
      onlineDevices: _findIntByKeys(data, const [
        'online_devices',
        'onlineDevices',
        'online_device',
        'onlineDevice',
        'device_online',
        'deviceOnline',
        'online',
      ]),
      maxDevices: _findIntByKeys(data, const [
        'max_devices',
        'maxDevices',
        'device_limit',
        'deviceLimit',
        'device_limit_count',
        'deviceLimitCount',
        'max_device',
        'maxDevice',
      ]),
      customerService: parseCustomerService(data),
    );
  }

  static String? parseCustomerService(Object? responseData) {
    final data = _decodeIfString(responseData);
    final value = _findStringByKeys(data, const [
      'customer_service',
      'customerService',
      'customer_service_url',
      'customerServiceUrl',
      'customer_service_link',
      'customerServiceLink',
    ]);
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _findSubscriptionUrl(Object? data) {
    final value = _findStringByKeys(data, const [
      'subscribe_url',
      'subscribeUrl',
      'subscription_url',
      'subscriptionUrl',
      'clash_url',
      'clashUrl',
      'mihomo_url',
      'mihomoUrl',
      'url',
    ]);
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return _findUrlString(data);
  }

  static String? _resolveSubscribeUrl(String? value, String? baseUrl) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) return _ensureHiddifySubscribeFlag(uri).toString();

    final base = Uri.tryParse(baseUrl?.trim() ?? '');
    if (base == null || !base.hasScheme) return trimmed;

    if (trimmed.startsWith('//')) {
      final protocolRelative = Uri.tryParse('${base.scheme}:$trimmed');
      return protocolRelative == null
          ? '${base.scheme}:$trimmed'
          : _ensureHiddifySubscribeFlag(protocolRelative).toString();
    }
    return _ensureHiddifySubscribeFlag(base.resolve(trimmed)).toString();
  }

  static Uri _ensureHiddifySubscribeFlag(Uri uri) {
    if (!_isXBoardSubscribeUri(uri)) return uri;
    if (uri.queryParameters.keys.any((key) => key.toLowerCase() == 'flag')) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, 'flag': 'hiddify'});
  }

  static bool _isXBoardSubscribeUri(Uri uri) {
    final path = uri.path.toLowerCase();
    return path == '/api/v1/client/subscribe' || path.endsWith('/api/v1/client/subscribe');
  }

  static String? _findPlanName(Object? data) {
    final direct = _findStringByKeys(data, const [
      'plan_name',
      'planName',
      'package_name',
      'packageName',
      'product_name',
      'productName',
      'group_name',
      'groupName',
    ]);
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();

    for (final containerKey in const ['plan', 'subscribe', 'subscription', 'package', 'product']) {
      final container = _findValueByKeys(data, [containerKey]);
      if (container is String && container.trim().isNotEmpty) return container.trim();
      final name = _findStringByKeys(container, const ['name', 'title', 'subject']);
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }

    return null;
  }

  static Object? _decodeIfString(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return value;
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return value;
      }
    }
    return value;
  }

  static String _stripBearer(String token) {
    const prefix = 'Bearer ';
    var value = token.trim();
    while (value.toLowerCase().startsWith(prefix.toLowerCase())) {
      value = value.substring(prefix.length).trim();
    }
    return value;
  }

  static String _normalizeBearer(String authData) {
    final token = _stripBearer(authData);
    return 'Bearer $token';
  }

  static String? _findStringByKeys(Object? value, List<String> keys) {
    final found = _findValueByKeys(value, keys);
    if (found == null) return null;
    if (found is String) return found;
    if (found is Map || (found is Iterable && found is! String)) return null;
    return found.toString();
  }

  static int? _findIntByKeys(Object? value, List<String> keys) {
    final found = _findValueByKeys(value, keys);
    if (found == null) return null;
    if (found is int) return found;
    if (found is double) return found.round();
    if (found is num) return found.toInt();
    return int.tryParse(found.toString());
  }

  static bool? _findBoolByKeys(Object? value, List<String> keys) {
    final found = _findValueByKeys(value, keys);
    if (found == null) return null;
    if (found is bool) return found;
    if (found is num) return found != 0;
    final text = found.toString().trim().toLowerCase();
    if (text.isEmpty) return null;
    if (const {'1', 'true', 'yes', 'y', 'on'}.contains(text)) return true;
    if (const {'0', 'false', 'no', 'n', 'off'}.contains(text)) return false;
    return null;
  }

  static DateTime? _findDateTimeByKeys(Object? value, List<String> keys) {
    final found = _findValueByKeys(value, keys);
    if (found == null) return null;
    if (found is DateTime) return found;
    if (found is num) {
      final raw = found.toInt();
      if (raw <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(raw > 9999999999 ? raw : raw * 1000);
    }
    final text = found.toString().trim();
    if (text.isEmpty) return null;
    final asInt = int.tryParse(text);
    if (asInt != null) {
      if (asInt <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(asInt > 9999999999 ? asInt : asInt * 1000);
    }
    return DateTime.tryParse(text);
  }

  static Object? _findValueByKeys(Object? value, List<String> keys) {
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (keys.any((candidate) => candidate.toLowerCase() == key.toLowerCase())) {
          return entry.value;
        }
      }
      for (final entry in value.entries) {
        final nested = _findValueByKeys(entry.value, keys);
        if (nested != null) return nested;
      }
    } else if (value is Iterable) {
      for (final item in value) {
        final nested = _findValueByKeys(item, keys);
        if (nested != null) return nested;
      }
    }
    return null;
  }

  static String? _findUrlString(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        final nested = _findUrlString(entry.value);
        if (nested != null) return nested;
      }
    } else if (value is Iterable && value is! String) {
      for (final item in value) {
        final nested = _findUrlString(item);
        if (nested != null) return nested;
      }
    } else if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
    }
    return null;
  }
}
