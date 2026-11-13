import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_session.freezed.dart';

/// A signed-in contributor's tokens, as kept on the phone.
@freezed
abstract class AuthSession with _$AuthSession {
  const factory AuthSession({
    required String email,
    required String accessToken,
    required DateTime accessExpiresAt,
    required String refreshToken,
    required DateTime refreshExpiresAt,
  }) = _AuthSession;

  const AuthSession._();

  /// The access token can be sent at [now] (with [margin] to spare for the
  /// request to reach the server).
  bool accessUsableAt(
    DateTime now, {
    Duration margin = const Duration(seconds: 30),
  }) => now.add(margin).isBefore(accessExpiresAt);

  /// The refresh token can still be exchanged at [now].
  bool refreshUsableAt(DateTime now) => now.isBefore(refreshExpiresAt);
}

/// [AuthSession] as stored (JSON), and back.
extension AuthSessionJson on AuthSession {
  Map<String, Object?> toJson() => {
    'email': email,
    'access_token': accessToken,
    'access_expires_at': accessExpiresAt.toUtc().toIso8601String(),
    'refresh_token': refreshToken,
    'refresh_expires_at': refreshExpiresAt.toUtc().toIso8601String(),
  };
}

/// Reads what [AuthSessionJson.toJson] wrote; throws on anything else.
AuthSession authSessionFromJson(Map<String, Object?> json) => AuthSession(
  email: json['email']! as String,
  accessToken: json['access_token']! as String,
  accessExpiresAt: DateTime.parse(json['access_expires_at']! as String),
  refreshToken: json['refresh_token']! as String,
  refreshExpiresAt: DateTime.parse(json['refresh_expires_at']! as String),
);

/// Whether someone is signed in on this phone.
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.signedOut() = SignedOut;

  const factory AuthState.signedIn({required String email}) = SignedIn;
}
