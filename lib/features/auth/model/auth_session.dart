import 'package:hiddify/features/auth/model/user_subscription.dart';

class AuthSession {
  const AuthSession({
    required this.authData,
    required this.email,
    required this.createdAt,
    this.subscribeToken,
    this.subscription,
  });

  final String authData;
  final String email;
  final DateTime createdAt;
  final String? subscribeToken;
  final UserSubscription? subscription;

  AuthSession copyWith({
    String? authData,
    String? email,
    DateTime? createdAt,
    String? subscribeToken,
    UserSubscription? subscription,
  }) {
    return AuthSession(
      authData: authData ?? this.authData,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      subscribeToken: subscribeToken ?? this.subscribeToken,
      subscription: subscription ?? this.subscription,
    );
  }
}
