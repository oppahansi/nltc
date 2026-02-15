// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/models/data_entities.dart";
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/utils/screen_sizes.dart";

List<Widget> buildCalculatorTabs(
  BuildContext context,
  WidgetRef ref,
  List<TalentTree> talentTrees,
) {
  final settings = ref.watch(settingsProvider).value!;
  final themeColor = settings.classColor;

  return talentTrees
      .map(
        (entry) => Tab(
          child: Container(
            width: screenWidth(context, 0.08),
            height: screenWidth(context, 0.08),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(_getTreeIcon(entry)),
                fit: BoxFit.fill,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: themeColor, width: 2.0),
            ),
          ),
        ),
      )
      .toList();
}

String _getTreeIcon(TalentTree tree) {
  return "assets/images/icons/${tree.icon}.webp";
}
