// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/navigation/route_paths.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/widgets/saved_build_tile.dart";
import "package:ltc/core/widgets/shared.dart";
import "package:ltc/features/calculator/providers/calculator_providers.dart";
import "package:ltc/l10n/app_localizations.dart";

class SavedBuilds extends ConsumerStatefulWidget {
  const SavedBuilds({super.key});

  @override
  ConsumerState<SavedBuilds> createState() => _SavedBuildsState();
}

class _SavedBuildsState extends ConsumerState<SavedBuilds> {
  static const int _pageSize = 10;
  int _limit = _pageSize;

  void _loadMore() {
    setState(() {
      _limit += _pageSize;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value!;
    final expColor = settings.expColor;

    final fetchLimit = _limit + 1;
    final buildsAsync = ref.watch(savedBuildsProvider(fetchLimit));
    final loc = AppLocalizations.of(context)!;

    final style = isTablet(context) || isLargeTablet(context)
        ? displaySmall(context)
        : titleLarge(context);
    final currentScreen = ModalRoute.of(context)?.settings.name;
    final isOnHomeScreen =
        currentScreen == RoutePaths.home || currentScreen == "/";

    final noBuildsText = loc.no_saved_builds
        .text(style: bodyLarge(context).withColor(Colors.white70))
        .paddingAll(gapSize(context))
        .container(decoration: getDefaultBoxDecoration(expColor));

    return buildsAsync.when(
      data: (builds) {
        final hasMore = builds.length > _limit;
        final visible = builds.take(_limit).toList();
        final homeLimit = (_pageSize / 2).toInt();
        final displayVisible = isOnHomeScreen
            ? visible.take(homeLimit).toList()
            : visible;
        final itemCount =
            displayVisible.length + (!isOnHomeScreen && hasMore ? 1 : 0);

        final loadMoreTile = ListTile(
          dense: true,
          title: loc.load_more.text(style: style.withColor(settings.expColor)),
          trailing: Symbols.more_horiz.icon(
            color: expColor,
            size: gapSize(context),
          ),
          onTap: _loadMore,
        );

        final listView = ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: isOnHomeScreen ? displayVisible.length : itemCount,
          separatorBuilder: (_, _) =>
              Divider(color: expColor.withAlpha(75), height: 1),
          itemBuilder: (_, i) {
            // Load more row (only when not on home screen)
            if (!isOnHomeScreen && hasMore && i == displayVisible.length) {
              return loadMoreTile;
            }

            return SavedBuildTile(classBuild: displayVisible[i], limit: _limit);
          },
        ).container(decoration: getDefaultBoxDecoration(expColor));

        return [
          loc.recent_builds.capitalize().text(style: style.withColor(expColor)),
          if (builds.isEmpty) noBuildsText,
          if (builds.isNotEmpty) listView,
        ].column();
      },
      loading: () => Container(
        padding: const EdgeInsets.all(16),
        decoration: getDefaultBoxDecoration(expColor),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                '${loc.loading.capitalize()}...',
                style: bodyLarge(context).withColor(Colors.white70),
              ),
            ],
          ),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: getDefaultBoxDecoration(Colors.redAccent),
        child: Text(
          '${loc.error}: $e',
          style: bodyLarge(context).withColor(Colors.redAccent),
        ),
      ),
    );
  }
}
