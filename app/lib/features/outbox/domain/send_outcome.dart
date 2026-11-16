import 'dart:io';
import 'dart:math';

import 'package:qout/core/api/qout_api.dart';
import 'package:qout/features/contribute/data/contribution_repository.dart'
    show PhotoUploadError;

/// What happened to one outbox entry when it was sent.
sealed class SendOutcome {
  const SendOutcome();
}

/// Accepted (or already received: a resend of the same client id).
final class Sent extends SendOutcome {
  const Sent();
}

/// Try again later: no connection, the server busy or limiting. [after]:
/// when the server said (Retry-After); otherwise the backoff decides.
final class RetryLater extends SendOutcome {
  const RetryLater(this.message, {this.after});

  final String message;
  final Duration? after;
}

/// Needs a signed-in user: sent again after signing in.
final class NeedsSignIn extends SendOutcome {
  const NeedsSignIn();

  String get message => 'Sign in to send it.';
}

/// The server refused it for good (e.g. invalid values); never retried.
final class Refused extends SendOutcome {
  const Refused(this.message);

  final String message;
}

/// How a failed send continues, with words for the user.
SendOutcome outcomeOf(Object error) => switch (error) {
  ApiConnectionError() => const RetryLater('No connection to Qout.'),
  PhotoUploadError() => const RetryLater('A photo could not be uploaded.'),
  ApiUnavailable(:final retryAfter) => RetryLater(
    'Qout is busy.',
    after: retryAfter,
  ),
  ApiTooManyRequests(:final retryAfter) => RetryLater(
    'Too many sent in a short time.',
    after: retryAfter,
  ),
  ApiUnauthorized() => const NeedsSignIn(),
  ApiInvalidRequest(:final message) => Refused('Not accepted: $message'),
  ApiNotFound() => const Refused('Not accepted: this product is unknown.'),
  ApiConflict(:final message) => Refused('Not accepted: $message'),
  ApiBadResponse(:final statusCode?) when statusCode < 500 => Refused(
    'Not accepted (HTTP $statusCode).',
  ),
  ApiBadResponse() => const RetryLater('Qout had a problem.'),
  FileSystemException() => const Refused(
    'A photo is missing on this phone. Delete it and add the product again.',
  ),
  FormatException() => const Refused('This entry is damaged. Delete it.'),
  _ => const RetryLater('Something went wrong.'),
};

/// First retry after this long, doubling with each failure...
const outboxFirstRetry = Duration(seconds: 30);

/// ...up to this.
const outboxMaxRetry = Duration(hours: 1);

/// When to try again after [failures] failed attempts (counting this one):
/// exponential backoff with ±20 % jitter, so many phones coming back online
/// don't all retry at once.
Duration retryDelay(int failures, Random random) {
  final doublings = min(max(failures - 1, 0), 20);
  final base = min(
    outboxFirstRetry.inMilliseconds * pow(2, doublings),
    outboxMaxRetry.inMilliseconds,
  );
  final jitter = 0.8 + 0.4 * random.nextDouble();
  return Duration(milliseconds: (base * jitter).round());
}
