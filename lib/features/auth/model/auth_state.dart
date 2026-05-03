import 'package:hiddify/features/auth/model/auth_session.dart';

class AuthState {
  const AuthState({this.session});

  final AuthSession? session;

  bool get isLoggedIn => session != null;

  AuthState copyWith({AuthSession? session}) {
    return AuthState(session: session ?? this.session);
  }
}
