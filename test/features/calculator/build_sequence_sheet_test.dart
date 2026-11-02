// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/widgets/build_sequence_sheet.dart";
import "package:ltc/l10n/app_localizations.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

const _vanilla = 1;
const _forever = 7;

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

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Future<void> select(WidgetTester tester, int expansionId) async {
    await tester.runAsync(() async {
      await container.read(settingsProvider.future);
      await container
          .read(settingsProvider.notifier)
          .setSetting(settingsKeySelectedExpId, "$expansionId");
      await container.read(buildStateProvider.future);
      await container.read(buildStateProvider.notifier).startNewBuild();
    });
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: BuildSequenceSheet()),
        ),
      ),
    );
    await settle(tester);
  }

  /// Spends a point in the first tree of each side, returning their talents.
  (Talent, Talent?) spendPoints() {
    final notifier = container.read(buildStateProvider.notifier);
    final trees = container.read(buildStateProvider).value!.talentTreeTalents;
    final talent = trees[0].firstWhere((t) => t.row == 0);
    notifier.addPoint(talent);
    if (trees.length <= firstLegacyTreeId) return (talent, null);
    final perk = trees[firstLegacyTreeId].firstWhere((t) => t.column == 0);
    notifier.addPoint(perk);
    return (talent, perk);
  }

  testWidgets("Forever splits talents and Legacy perks into tabs", (
    tester,
  ) async {
    await select(tester, _forever);
    final (talent, perk) = spendPoints();
    await pump(tester);

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text(talent.names["en"]!), findsOneWidget);
    expect(find.text(perk!.names["en"]!), findsNothing);

    await tester.tap(find.text("Legacy"));
    await settle(tester);

    expect(find.text(perk.names["en"]!), findsOneWidget);
    expect(find.text(talent.names["en"]!), findsNothing);
    expect(find.text("1"), findsOneWidget, reason: "Numbered on its own");
  });

  testWidgets("a tab without points says so", (tester) async {
    await select(tester, _forever);
    final notifier = container.read(buildStateProvider.notifier);
    final trees = container.read(buildStateProvider).value!.talentTreeTalents;
    notifier.addPoint(trees[0].firstWhere((t) => t.row == 0));
    await pump(tester);

    await tester.tap(find.text("Legacy"));
    await settle(tester);

    expect(find.text("No points spent."), findsOneWidget);
  });

  testWidgets("other editions have no tabs", (tester) async {
    await select(tester, _vanilla);
    final (talent, _) = spendPoints();
    await pump(tester);

    expect(find.byType(TabBar), findsNothing);
    expect(find.text(talent.names["en"]!), findsOneWidget);
  });
}
