// Flutter Imports
import "package:flutter/material.dart";
import "package:flutter/services.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/services/settings_service.dart";
import "package:ltc/features/builds/builds_screen.dart";
import "package:ltc/features/calculator/talent_calculator_screen.dart";
import "package:ltc/features/home/home_screen.dart";
import "package:ltc/features/settings/settings_screen.dart";
import "package:ltc/l10n/app_localizations.dart";

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

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      data: (settings) => MaterialApp(
        title: "LTC",
        locale: settings.locale,
        debugShowCheckedModeBanner: false,
        supportedLocales: const [Locale("en", ""), Locale("de", "")],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: HomeScreen(),
        routes: {
          HomeScreen.path: (context) => HomeScreen(),
          BuildsScreen.path: (context) => BuildsScreen(),
          SettingsScreen.path: (context) => SettingsScreen(),
          TalentCalculatorScreen.path: (context) => TalentCalculatorScreen(),
        },
        onUnknownRoute: (settings) =>
            MaterialPageRoute(builder: (context) => HomeScreen()),
      ),
      loading: () => CircularProgressIndicator().center(),
      error: (e, st) => "Error: $e".text().center(),
    );
  }
}
