// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/game/data_repo.dart";
import "package:ltc/core/settings/setting_keys.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/widgets/glyphs_view.dart";
import "package:ltc/l10n/app_localizations.dart";

// Relative Project Imports
import "../../helpers/test_db.dart";

const _wotlk = 3;
const _mage = 2;

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

  Future<List<Glyph>> open(WidgetTester tester) async {
    late List<Glyph> glyphs;
    await tester.runAsync(() async {
      await container.read(settingsProvider.future);
      final settings = container.read(settingsProvider.notifier);
      await settings.setSetting(settingsKeySelectedExpId, "$_wotlk");
      await settings.setSetting(settingsKeySelectedClassId, "$_mage");
      await container.read(buildStateProvider.future);
      await container.read(buildStateProvider.notifier).startNewBuild();
      glyphs = await DataRepo().getGlyphs(expansionId: _wotlk, classId: _mage);
    });
    tester.view.physicalSize = const Size(1344, 2992);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: GlyphsView()),
        ),
      ),
    );
    await settle(tester);
    return glyphs;
  }

  testWidgets("a slot's picker offers only its type, without used ones", (
    tester,
  ) async {
    final glyphs = await open(tester);
    final majors = glyphs.where((g) => g.type == GlyphType.major).toList();
    final minor = glyphs.firstWhere((g) => g.type == GlyphType.minor);

    expect(find.text("Empty slot"), findsNWidgets(6));

    await tester.tap(find.text("Empty slot").first);
    await settle(tester);
    expect(find.text("Choose a major glyph"), findsOneWidget);
    expect(find.text(minor.name), findsNothing);

    await tester.tap(find.text(majors.first.name));
    await settle(tester);
    expect(find.text("Choose a major glyph"), findsNothing);
    expect(find.text(majors.first.name), findsOneWidget);
    expect(find.text("Empty slot"), findsNWidgets(5));
    expect(container.read(buildStateProvider).value!.glyphIds, [
      majors.first.id,
    ]);

    await tester.tap(find.text("Empty slot").first);
    await settle(tester);
    expect(find.textContaining("Already in this build"), findsOneWidget);
  });

  testWidgets("a filled slot can be emptied", (tester) async {
    final glyphs = await open(tester);
    container
        .read(buildStateProvider.notifier)
        .chooseGlyph(glyphs.first, glyphs);
    await settle(tester);

    await tester.tap(find.byTooltip("Remove glyph"));
    await settle(tester);

    expect(find.text("Empty slot"), findsNWidgets(6));
    expect(container.read(buildStateProvider).value!.glyphIds, isEmpty);
  });
}
