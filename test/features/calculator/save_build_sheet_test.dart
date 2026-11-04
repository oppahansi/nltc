// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/widgets/save_build_sheet.dart";
import "package:ltc/l10n/app_localizations.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

void main() {
  late Directory dir;
  late ProviderContainer container;

  setUp(() async {
    dir = await setUpTestDb();
    container = ProviderContainer();
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDb(dir);
  });

  testWidgets("what was typed survives the keyboard closing", (tester) async {
    await tester.runAsync(() async {
      await container.read(settingsProvider.future);
      await container.read(buildStateProvider.future);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Material(child: SaveBuildSheet()),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(TextField), "PvP");
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(find.text("PvP"), findsOneWidget);
  });
}
