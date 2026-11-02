// Flutter Imports
import "package:flutter/material.dart";
import "package:flutter/services.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/app/app.dart";
import "package:ltc/core/db/db.dart";
import "package:ltc/core/services/settings_service.dart";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await Db.initializeDataDb();
  await Db.initializeUserDb();
  await SettingsService().initSettings();

  runApp(const ProviderScope(child: MyApp()));
}
