// Flutter Imports
import "package:flutter/material.dart";
import "package:flutter/services.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:exui/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/game/game_catalog.dart";
import "package:ltc/core/navigation/route_paths.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/features/builds/widgets/saved_builds.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/home/widgets/class_selection.dart";
import "package:ltc/features/home/widgets/expansion_selection.dart";
import "package:ltc/features/home/widgets/home_button.dart";
import "package:ltc/l10n/app_localizations.dart";

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime? lastBackPressTime;

  late Image bgImage;

  @override
  initState() {
    super.initState();

    bgImage = Image.asset(getRngBgImagePath(), fit: BoxFit.cover);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value!;
    final expColor = settings.expColor;
    final loc = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async => _checkPop(didPop),
      child: Scaffold(
        backgroundColor: Colors.black,
        body:
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: [
                const ExpansionSelection(),
                gapSize(context).gapColumn,
                const ClassSelection(),
                gapSize(context).gapColumn,
                Divider(color: expColor.withAlpha(150), thickness: 1),
                gapSize(context).gapColumn,
                HomeButton(
                  icon: Symbols.school,
                  title: loc.plan_build,
                  path: RoutePaths.calculator,
                  onTap: () async {
                    await ref.read(buildStateProvider.notifier).startNewBuild();
                  },
                ),
                HomeButton(
                  icon: Symbols.download,
                  title: loc.load_build,
                  path: RoutePaths.builds,
                ),
                HomeButton(
                  icon: Symbols.settings,
                  path: RoutePaths.settings,
                  title: loc.settings.capitalize(),
                ),
                gapSize(context).gapColumn,
                Divider(color: expColor.withAlpha(150), thickness: 1),
                gapSize(context).gapColumn,
                const SavedBuilds(),
              ].column(crossAxisAlignment: CrossAxisAlignment.center),
            ).imageBox(
              image: AssetImage(getRngBgImagePath()),
              opacity: 0.5,
              fit: BoxFit.fill,
            ),
      ),
    ).safeAreaAll().blackBox();
  }

  void _checkPop(bool didPop) {
    final loc = AppLocalizations.of(context)!;

    if (didPop) return;

    final modalRoute = ModalRoute.of(context);
    if (modalRoute?.isCurrent == false) {
      context.pop();
      return;
    }

    final now = DateTime.now();
    const duration = Duration(seconds: 2);

    if (lastBackPressTime == null ||
        now.difference(lastBackPressTime!) > duration) {
      lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.prompt_for_exit), duration: duration),
      );

      return;
    }

    lastBackPressTime = null;
    SystemNavigator.pop();
  }
}
