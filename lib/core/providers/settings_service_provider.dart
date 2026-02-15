// Package Imports
import "package:riverpod_annotation/riverpod_annotation.dart";

// Project Imports
import "package:ltc/core/models/settings.dart";
import "package:ltc/core/services/settings_service.dart";

part "settings_service_provider.g.dart";

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  @override
  FutureOr<Settings> build() async {
    final service = SettingsService();
    await service.initSettings();

    return SettingsService.getSettings();
  }

  Future<void> setSetting(String key, String value) async {
    final service = SettingsService();
    await service.setSetting(key, value);

    state = AsyncData(SettingsService.getSettings());
  }
}
