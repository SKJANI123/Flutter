/// Minimal localization. Default English with a small set of translations.
/// Add more keys/languages as needed.
class L10n {
  L10n(this.languageCode);

  final String languageCode;

  static const supported = ['en', 'hi', 'es', 'fr'];

  String tr(String en, Map<String, String> translations) =>
      translations[languageCode] ?? en;

  String get home => tr('Home', const {});
  String get liveAlerts => _t('Live Alerts', {'hi': 'लाइव अलर्ट'});
  String get map => _t('Map', const {});
  String get sos => _t('SOS', const {});
  String get contacts => tr('Contacts', const {'hi': 'संपर्क'});
  String get shelters => tr('Shelters', const {});
  String get history => tr('Alert History', const {'hi': 'अलर्ट इतिहास'});
  String get settings => tr('Settings', const {'hi': 'सेटिंग्स'});
  String get ok => tr('OK', const {});
  String get cancel => tr('Cancel', const {});
  String get save => tr('Save', const {});
  String get delete => tr('Delete', const {});
  String get retry => tr('Retry', const {});
  String get enable => tr('Enable', const {});
  String get disable => tr('Disable', const {});
  String get denied => tr('Denied', const {});
  String get granted => tr('Granted', const {});
  String get allow => tr('Allow', const {});
  String get networkOffline => tr(
    'You are offline. Showing cached data.',
    const {'hi': 'आप ऑफ़लाइन हैं।'},
  );
  String get networkOnline =>
      tr('Back online — syncing data.', const {'hi': 'ऑनलाइन — डेटा सिंक।'});
  String get gpsDisabled => tr('Location services are disabled.', const {});
  String get locationDenied => tr('Location permission denied.', const {});
  String get noDisasters => tr('No active disasters in your area.', const {
    'hi': 'कोई सक्रिय आपदा नहीं।',
  });
  String get loading => tr('Loading…', const {});
  String get kmAway => tr('km away', const {});
  String get evacuated => tr('Safe places nearby', const {});

  String _t(String en, Map<String, String> m) => tr(en, m);
}
