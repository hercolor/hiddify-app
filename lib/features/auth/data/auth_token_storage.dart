import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hiddify/features/auth/model/auth_session.dart';
import 'package:hiddify/features/auth/model/user_subscription.dart';

abstract interface class AuthTokenStorage {
  Future<void> save(AuthSession session);
  Future<AuthSession?> read();
  Future<void> clear();
}

class SecureAuthTokenStorage implements AuthTokenStorage {
  SecureAuthTokenStorage(this._storage);

  static const _authDataKey = 'xboard.auth.auth_data';
  static const _legacyTokenKey = 'xboard.auth.token';
  static const _subscribeTokenKey = 'xboard.auth.subscribe_token';
  static const _emailKey = 'xboard.auth.email';
  static const _createdAtKey = 'xboard.auth.created_at';
  static const _subscribeUrlKey = 'xboard.auth.subscribe_url';
  static const _expiredAtKey = 'xboard.auth.expired_at';
  static const _uploadKey = 'xboard.auth.upload';
  static const _downloadKey = 'xboard.auth.download';
  static const _transferEnableKey = 'xboard.auth.transfer_enable';
  static const _planNameKey = 'xboard.auth.plan_name';
  static const _onlineDevicesKey = 'xboard.auth.online_devices';
  static const _maxDevicesKey = 'xboard.auth.max_devices';
  static const _customerServiceKey = 'xboard.auth.customer_service';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(AuthSession session) async {
    await _storage.write(key: _authDataKey, value: session.authData);
    await _storage.write(key: _subscribeTokenKey, value: session.subscribeToken);
    await _storage.write(key: _emailKey, value: session.email);
    await _storage.write(key: _createdAtKey, value: session.createdAt.toIso8601String());

    final subscription = session.subscription;
    await _storage.write(key: _subscribeUrlKey, value: subscription?.subscribeUrl);
    await _storage.write(key: _expiredAtKey, value: subscription?.expiredAt?.toIso8601String());
    await _storage.write(key: _uploadKey, value: subscription?.upload.toString());
    await _storage.write(key: _downloadKey, value: subscription?.download.toString());
    await _storage.write(key: _transferEnableKey, value: subscription?.transferEnable.toString());
    await _storage.write(key: _planNameKey, value: subscription?.planName);
    await _storage.write(key: _onlineDevicesKey, value: subscription?.onlineDevices?.toString());
    await _storage.write(key: _maxDevicesKey, value: subscription?.maxDevices?.toString());
    await _storage.write(key: _customerServiceKey, value: subscription?.customerService);
  }

  @override
  Future<AuthSession?> read() async {
    final authData = await _storage.read(key: _authDataKey);
    final email = await _storage.read(key: _emailKey);
    if (authData == null || authData.isEmpty || email == null || email.isEmpty) {
      return null;
    }

    final createdAtText = await _storage.read(key: _createdAtKey);
    final subscribeToken = await _storage.read(key: _subscribeTokenKey);
    final subscribeUrl = await _storage.read(key: _subscribeUrlKey);
    final expiredAtText = await _storage.read(key: _expiredAtKey);

    return AuthSession(
      authData: authData,
      email: email,
      createdAt: DateTime.tryParse(createdAtText ?? '') ?? DateTime.now(),
      subscribeToken: subscribeToken == null || subscribeToken.isEmpty ? null : subscribeToken,
      subscription: subscribeUrl == null || subscribeUrl.isEmpty
          ? null
          : UserSubscription(
              subscribeUrl: subscribeUrl,
              expiredAt: DateTime.tryParse(expiredAtText ?? ''),
              upload: int.tryParse(await _storage.read(key: _uploadKey) ?? '') ?? 0,
              download: int.tryParse(await _storage.read(key: _downloadKey) ?? '') ?? 0,
              transferEnable: int.tryParse(await _storage.read(key: _transferEnableKey) ?? '') ?? 0,
              planName: await _storage.read(key: _planNameKey),
              onlineDevices: int.tryParse(await _storage.read(key: _onlineDevicesKey) ?? ''),
              maxDevices: int.tryParse(await _storage.read(key: _maxDevicesKey) ?? ''),
              customerService: await _storage.read(key: _customerServiceKey),
            ),
    );
  }

  @override
  Future<void> clear() async {
    for (final key in [
      _authDataKey,
      _legacyTokenKey,
      _subscribeTokenKey,
      _emailKey,
      _createdAtKey,
      _subscribeUrlKey,
      _expiredAtKey,
      _uploadKey,
      _downloadKey,
      _transferEnableKey,
      _planNameKey,
      _onlineDevicesKey,
      _maxDevicesKey,
      _customerServiceKey,
    ]) {
      await _storage.delete(key: key);
    }
  }
}
