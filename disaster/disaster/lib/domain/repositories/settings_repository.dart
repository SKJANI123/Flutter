import 'package:disaster/domain/entities/app_settings.dart';

abstract class SettingsRepository {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
  Future<void> setOnboardingCompleted(bool value);
}
