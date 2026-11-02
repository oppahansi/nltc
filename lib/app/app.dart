// Flutter Imports
import "package:flutter/material.dart";
import "package:flutter_localizations/flutter_localizations.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/app/routes.dart";
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/features/home/home_screen.dart";
import "package:ltc/l10n/app_localizations.dart";

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
        home: const HomeScreen(),
        routes: appRoutes,
        onUnknownRoute: (settings) =>
            MaterialPageRoute(builder: (context) => const HomeScreen()),
      ),
      loading: () => CircularProgressIndicator().center(),
      error: (e, st) => "Error: $e".text().center(),
    );
  }
}
