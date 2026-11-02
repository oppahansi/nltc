// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/db/db.dart";
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/edition.dart";
import "package:ltc/core/game/editions.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/features/home/widgets/expansion_selection.dart";
import "package:ltc/l10n/app_localizations.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

Expansion expansion(int id, Edition edition, String? era) =>
    Expansion(id: id, code: "$id", edition: edition, era: era, names: const {});

void main() {
  final originalTbc = expansion(2, Edition.original, "tbc");
  final classicTbc = expansion(5, Edition.classic, "tbc");
  final classicVanilla = expansion(4, Edition.classic, "vanilla");
  final forever = expansion(7, Edition.forever, null);

  test("switching edition keeps the era where it exists", () {
    final all = [originalTbc, classicVanilla, classicTbc, forever];
    expect(availableEditions(all), Edition.values);
    expect(expansionAfterSwitch(all, originalTbc, Edition.classic), classicTbc);
    expect(expansionAfterSwitch(all, classicTbc, Edition.forever), forever);
    expect(expansionAfterSwitch(all, forever, Edition.classic), classicVanilla);
  });

  group("edition picker", () {
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

    Future<void> pump(WidgetTester tester) async {
      Future<void> settle() async {
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      await tester.runAsync(() => container.read(settingsProvider.future));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ExpansionSelection()),
          ),
        ),
      );
      await settle();
    }

    testWidgets("stays hidden while only Original has data", (tester) async {
      await pump(tester);
      expect(find.byType(SegmentedButton<Edition>), findsNothing);
      expect(find.text("TBC"), findsOneWidget);
    });

    testWidgets("switches to the same era in Classic", (tester) async {
      await tester.runAsync(() async {
        final db = await Db.getDataDbInstance();
        await db.insert("expansions", {
          "id": 5,
          "code": "classic_tbc",
          "edition": "classic",
          "era": "tbc",
        });
        await db.insert("expansion_names", {
          "expansionId": 5,
          "languageCode": "en",
          "name": "TBC",
        });
        await db.execute(
          "INSERT INTO talents SELECT classId, talentTreeId, id + 10000, row, "
          '"column", icon, NULL, 5 FROM talents WHERE expansion = 2',
        );
      });

      await pump(tester);
      expect(find.byType(SegmentedButton<Edition>), findsOneWidget);
      expect(
        find.text("Vanilla"),
        findsOneWidget,
        reason: "Original is selected",
      );

      Future<void> waitForChange() async {
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
        }
      }

      await tester.tap(find.text("TBC"));
      await waitForChange();
      expect(container.read(settingsProvider).value!.selectedExpId, 2);

      await tester.tap(find.text("Classic"));
      await waitForChange();

      expect(container.read(settingsProvider).value!.selectedExpId, 5);
      expect(
        find.text("Vanilla"),
        findsNothing,
        reason: "Classic has only TBC",
      );
    });
  });
}
