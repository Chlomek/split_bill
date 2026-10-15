/// Base class for domain-level failure and error modeling.
abstract class Failure {
  final String message;
  final String? code;

  const Failure(this.message, {this.code});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' (code: $code)' : ''}';
}

/// Generic server or network failure.
class ServerFailure extends Failure {
  const ServerFailure([super.message = 'A server error occurred. Please try again.']);
}

/// OCR or image scanning failure.
class ScanFailure extends Failure {
  const ScanFailure([super.message = 'Failed to scan receipt image.']);
}

/// User exceeded their tier quota (e.g. AI scans or group limit).
class QuotaExceededFailure extends Failure {
  const QuotaExceededFailure([super.message = 'Free quota exceeded. Upgrade to Premium for unlimited access.']);
}

/// Auth or session failure.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication required.']);
}
