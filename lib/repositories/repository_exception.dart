import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Why a repository operation failed. Screens switch on this instead of
/// parsing exception strings.
enum RepositoryErrorCode {
  /// No authenticated user is available for an operation that needs one.
  notSignedIn,

  /// The requested record does not exist.
  notFound,

  /// Email or password did not match an account.
  invalidCredentials,

  /// An account already exists for the supplied email.
  emailInUse,

  /// The password is shorter than the minimum length.
  weakPassword,

  /// The account exists but an administrator has suspended it.
  accountSuspended,

  /// The caller supplied invalid data (empty field, malformed email, ...).
  invalidInput,

  /// The device could not reach the backend.
  network,

  /// A file upload or download failed.
  storage,

  /// Firestore rejected the read or write.
  permission,

  /// Anything not covered above.
  unknown,
}

/// The single error type thrown by [IRepository] implementations.
///
/// [message] is already user-facing, so the UI can show it directly.
class RepositoryException implements Exception {
  final RepositoryErrorCode code;
  final String message;
  final Object? cause;

  const RepositoryException(this.code, this.message, {this.cause});

  /// Translates a backend error into a typed, user-facing exception.
  factory RepositoryException.from(Object error) {
    if (error is RepositoryException) return error;

    if (error is fb.FirebaseAuthException) {
      return _auth(error);
    }
    if (error is FirebaseException) {
      return _firestore(error);
    }

    final text = _clean(error);
    return RepositoryException(RepositoryErrorCode.unknown, text, cause: error);
  }

  /// Message for any thrown object, safe to display in a snack bar.
  static String messageOf(Object error) => RepositoryException.from(error).message;

  /// True when the failure is a connectivity problem, either reported by the
  /// backend or raised locally as a socket/timeout error.
  static bool isNetwork(Object error) {
    if (error is RepositoryException) {
      return error.code == RepositoryErrorCode.network;
    }
    final text = error.toString().toLowerCase();
    return text.contains('network') ||
        text.contains('timed out') ||
        text.contains('timeout') ||
        text.contains('connection') ||
        text.contains('socket') ||
        text.contains('host lookup');
  }

  static RepositoryException _auth(fb.FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return RepositoryException(
          RepositoryErrorCode.invalidCredentials,
          'Incorrect email or password.',
          cause: error,
        );
      case 'email-already-in-use':
        return RepositoryException(
          RepositoryErrorCode.emailInUse,
          'An account with this email already exists.',
          cause: error,
        );
      case 'weak-password':
        return RepositoryException(
          RepositoryErrorCode.weakPassword,
          'Password must be at least 6 characters.',
          cause: error,
        );
      case 'invalid-email':
        return RepositoryException(
          RepositoryErrorCode.invalidInput,
          'Please enter a valid email address.',
          cause: error,
        );
      case 'user-disabled':
        return RepositoryException(
          RepositoryErrorCode.accountSuspended,
          'This account has been suspended.',
          cause: error,
        );
      case 'network-request-failed':
        return RepositoryException(
          RepositoryErrorCode.network,
          'Network error. Check your connection and try again.',
          cause: error,
        );
      case 'too-many-requests':
        return RepositoryException(
          RepositoryErrorCode.unknown,
          'Too many attempts. Please try again shortly.',
          cause: error,
        );
      default:
        return RepositoryException(
          RepositoryErrorCode.unknown,
          error.message ?? 'Could not sign you in. Please try again.',
          cause: error,
        );
    }
  }

  static RepositoryException _firestore(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return RepositoryException(
          RepositoryErrorCode.notSignedIn,
          'You are not allowed to do that. Please sign in again.',
          cause: error,
        );
      case 'not-found':
        return RepositoryException(
          RepositoryErrorCode.notFound,
          'That record no longer exists.',
          cause: error,
        );
      case 'unavailable':
      case 'deadline-exceeded':
        return RepositoryException(
          RepositoryErrorCode.network,
          'Network error. Check your connection and try again.',
          cause: error,
        );
      case 'failed-precondition':
        return RepositoryException(
          RepositoryErrorCode.invalidInput,
          error.message ?? 'That action is not allowed right now.',
          cause: error,
        );
      default:
        return RepositoryException(
          RepositoryErrorCode.unknown,
          error.message ?? 'Something went wrong. Please try again.',
          cause: error,
        );
    }
  }

  /// Strips the `Exception: ` / `Bad state: ` prefixes that Dart adds so the
  /// raw text reads as a sentence.
  static String _clean(Object error) {
    final text = error.toString().trim();
    final match = RegExp(r'^(Exception|Bad state|Invalid argument)\s*:\s*').firstMatch(text);
    final cleaned = match == null ? text : text.substring(match.end);
    return cleaned.isEmpty ? 'Something went wrong. Please try again.' : cleaned;
  }

  @override
  String toString() => message;
}
