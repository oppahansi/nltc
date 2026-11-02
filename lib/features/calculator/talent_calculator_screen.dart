// Dart Imports
import "dart:async";

// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/providers/calculator_providers.dart";
import "package:ltc/features/calculator/utils/utility_methods.dart";
import "package:ltc/features/calculator/widgets/calculator_drawer.dart";
import "package:ltc/features/calculator/widgets/calculator_tabs.dart";
import "package:ltc/features/calculator/widgets/calculator_tutorial.dart";
import "package:ltc/features/calculator/widgets/talent_tree_view.dart";
import "package:ltc/l10n/app_localizations.dart";

class TalentCalculatorScreen extends ConsumerStatefulWidget {
  const TalentCalculatorScreen({super.key});

  @override
  ConsumerState<TalentCalculatorScreen> createState() =>
      _TalentCalculatorScreenState();
}

class _TalentCalculatorScreenState extends ConsumerState<TalentCalculatorScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  late final VoidCallback _tabAnimListener = _handleTabAnimation;
  bool _maybeAutoShown = false; // prevents duplicate auto-open

  Future<void> _animateTabAndWait(int targetIndex) async {
    final controller = _tabController;
    if (controller == null) return;

    if (controller.index == targetIndex && !controller.indexIsChanging) {
      return; // already there
    }

    final completer = Completer<void>();
    void listener() {
      if (!controller.indexIsChanging && controller.index == targetIndex) {
        controller.animation?.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    controller.animation?.addListener(listener);
    controller.animateTo(targetIndex);

    // Safety timeout in case listener never fires
    await completer.future.timeout(
      const Duration(milliseconds: 600),
      onTimeout: () {
        controller.animation?.removeListener(listener);
      },
    );
  }

  @override
  void dispose() {
    _tabController
      ?..removeListener(_handleTabChange)
      ..animation?.removeListener(_tabAnimListener)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value!;
    final classBuildAsync = ref.watch(buildStateProvider);
    final classColor = settings.classColor;

    return classBuildAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) =>
          Scaffold(body: Center(child: Text("Error loading data $e"))),
      data: (classBuild) {
        _ensureController(classBuild.talentTreeTalents.length);
        precacheBgs(context, classBuild.talentTrees);

        // Auto show tutorial once after data loaded
        if (!_maybeAutoShown && !hasSeenCalculatorTutorial()) {
          _maybeAutoShown = true;
          // Delay to allow first frame to render
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _showTutorial();
          });
        }

        return Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            iconTheme: IconThemeData(color: classColor),
            backgroundColor: Colors.black,
            title: TabBar(
              controller: _tabController,
              onTap: (i) =>
                  ref.read(treeIndexProvider.notifier).setTreeIndex(i),
              indicatorColor: classColor,
              dividerColor: Colors.black.withAlpha(150),
              tabs: buildCalculatorTabs(context, ref, classBuild.talentTrees),
            ),
            actions: [
              IconButton(
                tooltip: "Tutorial",
                icon: Symbols.help_outline.icon(size: gapSize(context) * 1.5),
                onPressed: _showTutorial,
              ),
            ],
          ),
          drawer: const CalculatorDrawer(),
          body: Stack(
            children: [
              TabBarView(
                controller: _tabController,
                children: classBuild.talentTrees
                    .map((t) => TalentTreeView(tree: t))
                    .toList(),
              ),
              FloatingActionButton(
                backgroundColor: classBuild.buildSequence.isNotEmpty
                    ? classColor
                    : classColor.withAlpha(75),
                foregroundColor: classBuild.buildSequence.isNotEmpty
                    ? Colors.black
                    : Colors.black54,
                elevation: classBuild.buildSequence.isNotEmpty ? 6 : 0,
                disabledElevation: 0,
                onPressed: classBuild.buildSequence.isNotEmpty
                    ? () async => _handleUndo(ref)
                    : null,
                child: Symbols.undo.icon(),
              ).positioned(
                right: gapSize(context),
                bottom: screenWidth(context, 0.1),
              ),
            ],
          ),
        ).safeArea();
      },
    );
  }

  void _handleUndo(WidgetRef ref) async {
    final settings = ref.watch(settingsProvider).value!;
    final classColor = settings.classColor;
    final loc = AppLocalizations.of(context)!;

    final notifier = ref.read(buildStateProvider.notifier);
    final talent = notifier.getLastTalent();
    if (talent == null) return;

    ref.read(treeIndexProvider.notifier).setTreeIndex(talent.id);

    await _animateTabAndWait(talent.talentTreeId);

    notifier.removeLastPoint();

    if (!mounted) return;
    context.clearSnackBars();

    if (!mounted) return;
    context.showSnackBar(
      SnackBar(
        backgroundColor: Colors.black,
        content: loc
            .removed_point_in(talent.names[settings.locale.languageCode]!)
            .text(style: bodyMedium(context).withColor(classColor)),
      ),
    );
  }

  void _handleTabChange() {
    if (_tabController == null) return;
    // Kept for tap fallback (index changes immediately on tap).
    ref.read(treeIndexProvider.notifier).setTreeIndex(_tabController!.index);
  }

  void _handleTabAnimation() {
    final c = _tabController;
    if (c == null) return;
    final v = c.animation?.value;
    if (v == null) return;
    final target = v.round(); // nearest tab the user is swiping toward
    if (target != ref.read(treeIndexProvider)) {
      ref.read(treeIndexProvider.notifier).setTreeIndex(target);
    }
  }

  void _ensureController(int length) {
    if (_tabController != null && _tabController!.length == length) {
      return;
    }
    _tabController
      ?..removeListener(_handleTabChange)
      ..animation?.removeListener(_tabAnimListener)
      ..dispose();
    _tabController = TabController(length: length, vsync: this);
    _tabController!.addListener(_handleTabChange);
    _tabController!.animation?.addListener(_tabAnimListener);
  }

  void _showTutorial() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CalculatorTutorialSheet(),
    );
  }
}
