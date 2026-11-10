import 'package:url_launcher/url_launcher.dart';

import 'package:disaster/domain/value_objects/coordinates.dart';

/// Opens device intents for emergency sharing: phone calls, SMS and map
/// links. All calls are guarded and return false on failure so the UI can
/// stay graceful (e.g. no SMS app installed).
class EmergencyLaunchers {
  EmergencyLaunchers._();

  static Future<bool> call(String phoneNumber) async {
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> sms(String phoneNumber, {String? body}) async {
    final uri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: body == null ? null : {'body': body},
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openMaps({
    required double lat,
    required double lng,
    String? label,
  }) async {
    final uri = Uri(
      scheme: 'geo',
      queryParameters: {'q': '$lat,$lng', 'label': label},
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        return await launchUrl(
          Uri.parse(
            'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
          ),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }

  /// Opens the OS emergency dialler pre-filled with the emergency number.
  static Future<bool> callEmergency() => call('112');

  /// Opens turn-by-turn navigation to a coordinate.
  static Future<bool> openDirections(Coordinates coordinates) =>
      openMaps(lat: coordinates.latitude, lng: coordinates.longitude);

  /// Opens an external (official source) URL in the browser.
  static Future<bool> openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
