/// Base class for all known application errors. The UI always catches these
/// explicitly and never lets a failure crash the app.
class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// Raised for HTTP errors (4xx/5xx).
class ApiException extends AppException {
  const ApiException(super.message, {this.statusCode, super.cause});
  final int? statusCode;
}

/// Raised for connectivity / timeout failures.
class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause});
}

/// Raised for WebSocket failures.
class WebSocketException extends AppException {
  const WebSocketException(super.message, {super.cause});
}

/// Raised when the GPS/location services are unavailable or permissions denied.
class LocationException extends AppException {
  const LocationException(super.message, {super.cause});
}

/// Raised for SQLite failures.
class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause});
}

/// Raised when push/local notification permissions are denied or unavailable.
class NotificationException extends AppException {
  const NotificationException(super.message, {super.cause});
}

/// Raised when a raw payload cannot be parsed into a domain model.
class ParseException extends AppException {
  const ParseException(super.message, {super.cause});
}

/// Raised for SOS dispatch failures.
class SosException extends AppException {
  const SosException(super.message, {super.cause});
}
