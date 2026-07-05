import 'package:hiddify/features/auth/model/auth_session.dart';

enum AuthStatus { initializing, loggedOut, loggedIn }

class AuthState {
  const AuthState._({required this.status, this.session});

  const AuthState.initializing() : this._(status: AuthStatus.initializing);

  const AuthState.loggedOut() : this._(status: AuthStatus.loggedOut);

  const AuthState.loggedIn(AuthSession session) : this._(status: AuthStatus.loggedIn, session: session);

  final AuthStatus status;

  final AuthSession? session;

  bool get isInitializing => status == AuthStatus.initializing;

  bool get isLoggedOut => status == AuthStatus.loggedOut;

  bool get isLoggedIn => status == AuthStatus.loggedIn && session != null;

  AuthState copyWith({AuthStatus? status, AuthSession? session}) {
    final nextStatus = status ?? this.status;
    final nextSession = session ?? this.session;
    return switch (nextStatus) {
      AuthStatus.initializing => const AuthState.initializing(),
      AuthStatus.loggedOut => const AuthState.loggedOut(),
      AuthStatus.loggedIn => nextSession == null ? const AuthState.loggedOut() : AuthState.loggedIn(nextSession),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is AuthState &&
      status == other.status &&
      session?.authData == other.session?.authData &&
      session?.subscription == other.session?.subscription;

  @override
  int get hashCode => Object.hash(status, session?.authData, session?.subscription);
}
