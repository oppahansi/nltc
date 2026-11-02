// Dart Imports
import "dart:io";

// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

// Project Imports
import "package:ltc/app/app.dart";
import "package:ltc/app/routes.dart";
import "package:ltc/core/navigation/route_paths.dart";
import "package:ltc/features/builds/builds_screen.dart";
import "package:ltc/features/calculator/talent_calculator_screen.dart";
import "package:ltc/features/home/home_screen.dart";
import "package:ltc/features/settings/settings_screen.dart";

// Relative Project Imports
import "helpers/test_db.dart";

void main() {
  late Directory dir;

  setUp(() async => dir = await setUpTestDb());
  tearDown(() => tearDownTestDb(dir));

  test("every route has a screen", () {
    expect(appRoutes.keys.toSet(), {
      RoutePaths.home,
      RoutePaths.builds,
      RoutePaths.settings,
      RoutePaths.calculator,
    });
  });

  testWidgets("the app starts and every screen opens", (tester) async {
    // Database work is real I/O, which needs real time to pass.
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    // Tests render text in a wide placeholder font, which overflows layouts that
    // fit with real fonts. Anything else is still a failure.
    final reportError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (!details.toString().contains("overflowed")) reportError!(details);
    };
    addTearDown(() => FlutterError.onError = reportError);

    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    for (var i = 0; i < 30 && find.byType(HomeScreen).evaluate().isEmpty; i++) {
      await settle();
    }
    final shown = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data);
    expect(find.byType(HomeScreen), findsOneWidget, reason: "Showing: $shown");

    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    for (final (path, screen) in [
      (RoutePaths.builds, BuildsScreen),
      (RoutePaths.settings, SettingsScreen),
      (RoutePaths.calculator, TalentCalculatorScreen),
    ]) {
      navigator.pushNamed(path);
      await settle();
      expect(find.byType(screen), findsOneWidget, reason: path);
      expect(tester.takeException(), isNull, reason: path);
      navigator.pop();
      await settle();
    }

    // Stop timers and close providers before the database goes away.
    await tester.pumpWidget(const SizedBox());
    await settle();
  });
}
