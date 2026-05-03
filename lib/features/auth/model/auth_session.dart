import 'package:hiddify/features/auth/model/user_subscription.dart';

class AuthSession {
  const AuthSession({required this.token, required this.email, required this.createdAt, this.subscription});

  final String token;
  final String email;
  final DateTime createdAt;
  final UserSubscription? subscription;

  AuthSession copyWith({String? token, String? email, DateTime? createdAt, UserSubscription? subscription}) {
    return AuthSession(
      token: token ?? this.token,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      subscription: subscription ?? this.subscription,
    );
  }
}
