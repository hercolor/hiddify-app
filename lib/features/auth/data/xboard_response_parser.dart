import 'dart:convert';

import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';

class XBoardResponseParser {
  const XBoardResponseParser._();

  static String parseToken(Object? responseData) {
    final data = _decodeIfString(responseData);
    final token = _findStringByKeys(data, const ['token', 'auth_data', 'access_token', 'accessToken', 'authorization']);
    if (token == null || token.trim().isEmpty) {
      throw const AuthFailure.badResponse('登录成功但未返回 token');
    }
    return _stripBearer(token.trim());
  }

  static UserSubscription parseSubscription(Object? responseData) {
    final data = _decodeIfString(responseData);
    final subscribeUrl = _findStringByKeys(data, const [
      'subscribe_url',
      'subscribeUrl',
      'subscription_url',
      'subscriptionUrl',
      'subscribe',
      'url',
    ]);
    if (subscribeUrl == null || subscribeUrl.trim().isEmpty) {
      throw const AuthFailure.badResponse('未获取到订阅链接');
    }

    return UserSubscription(
      subscribeUrl: subscribeUrl.trim(),
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
      transferEnable: _findIntByKeys(data, const ['transfer_enable', 'transferEnable', 'total', 'traffic']) ?? 0,
    );
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
    if (token.toLowerCase().startsWith(prefix.toLowerCase())) {
      return token.substring(prefix.length).trim();
    }
    return token;
  }

  static String? _findStringByKeys(Object? value, List<String> keys) {
    final found = _findValueByKeys(value, keys);
    if (found == null) return null;
    if (found is String) return found;
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
}
