// Flutter Imports
import "package:flutter/material.dart";

// Project Imports
import "package:ltc/core/navigation/route_paths.dart";
import "package:ltc/features/builds/builds_screen.dart";
import "package:ltc/features/calculator/talent_calculator_screen.dart";
import "package:ltc/features/home/home_screen.dart";
import "package:ltc/features/settings/settings_screen.dart";

final appRoutes = <String, WidgetBuilder>{
  RoutePaths.home: (context) => const HomeScreen(),
  RoutePaths.builds: (context) => const BuildsScreen(),
  RoutePaths.settings: (context) => const SettingsScreen(),
  RoutePaths.calculator: (context) => const TalentCalculatorScreen(),
};
