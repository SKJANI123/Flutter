import 'package:disaster/domain/entities/disaster.dart';
import 'package:disaster/domain/value_objects/coordinates.dart';

/// Thrown by a [DisasterSource] when the authoritative feed is unreachable.
/// Callers surface this as "source unavailable" — data is never faked.
class SourceUnavailableException implements Exception {
  const SourceUnavailableException(this.sourceId, this.message, [this.cause]);
  final String sourceId;
  final String message;
  final Object? cause;

  @override
  String toString() => 'SourceUnavailableException($sourceId): $message';
}

/// Result of fetching a source.
class SourceFetchResult {
  const SourceFetchResult({
    required this.sourceId,
    required this.incidents,
    this.fetchedAt,
  });

  final String sourceId;
  final List<Disaster> incidents;
  final DateTime? fetchedAt;
}

/// A real, authoritative incident feed (USGS, GDACS, national weather models,
/// ...). Implementations must map official payloads to [Disaster] entities and
/// throw a [SourceUnavailableException] — never fake data — when the feed is
/// down.
abstract class DisasterSource {
  String get id;
  String get name;
  String get description;

  /// Fetches incidents. [since] is the last successful watermark (for
  /// incremental pulls); [referencePoint] is the user's active location, used
  /// by location-based feeds (weather warnings).
  Future<SourceFetchResult> fetch({
    DateTime? since,
    Coordinates? referencePoint,
  });
}
