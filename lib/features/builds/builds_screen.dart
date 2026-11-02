// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/widgets/saved_builds.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/features/builds/widgets/share_code_import.dart";

class BuildsScreen extends ConsumerStatefulWidget {
  const BuildsScreen({super.key});

  @override
  ConsumerState<BuildsScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<BuildsScreen> {
  DateTime? lastBackPressTime;

  late Image bgImage;

  @override
  initState() {
    super.initState();

    bgImage = Image.asset(getRngBgImagePath(), fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            bgImage,
            Container(color: Colors.black.withAlpha(150)),
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ShareCodeImport(),
                  gapSize(context).gapColumn,
                  const SavedBuilds(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
