// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/game/data_entities.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/settings/settings_service.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/features/calculator/widgets/talent_detail_sheet.dart";

class TalentWidget extends ConsumerWidget {
  final Talent talent;

  const TalentWidget({super.key, required this.talent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Trigger rebuild on locale change
    final settingsAsync = ref.watch(settingsProvider);
    final currentLocaleCode =
        settingsAsync.value?.locale.languageCode ??
        SettingsService.getSettings().locale.languageCode;

    // Watch provider so UI reacts to rank / enablement changes
    final buildStateAsync = ref.watch(buildStateProvider);
    final buildNotifier = ref.read(buildStateProvider.notifier);

    if (buildStateAsync.isLoading) {
      return const SizedBox.shrink();
    }
    if (buildStateAsync.hasError) {
      return const SizedBox.shrink();
    }

    final enabled = buildNotifier.isTalentEnabled(talent);
    final maxedOut = talent.currentRank >= talent.ranks.length;

    String? tooltipMessage;
    final lang = currentLocaleCode;
    if (talent.currentRank > 0 &&
        talent.currentRank - 1 < talent.ranks.length) {
      tooltipMessage = talent.ranks[talent.currentRank - 1].descriptions[lang];
    } else if (talent.ranks.isNotEmpty) {
      tooltipMessage = talent.ranks.first.descriptions[lang];
    }
    // Fallback if new locale not yet merged in (brief race)
    tooltipMessage ??= talent.currentRank > 0
        ? talent.ranks[talent.currentRank - 1].descriptions.values.first
        : talent.ranks.first.descriptions.values.first;

    final screenPercent = 0.15;
    final width = screenWidth(context, screenPercent);
    final imagePath = "assets/images/icons/${talent.icon}.webp";

    Color? imageColor = Colors.black;
    if (enabled) {
      imageColor = null;
    } else if (talent.currentRank > 0) {
      imageColor = null;
    } else {
      imageColor = Colors.black;
    }

    Color? borderColor = Colors.green;

    if (enabled) {
      if (maxedOut) {
        borderColor = Colors.amber;
      } else {
        borderColor = Colors.green;
      }
    } else if (talent.currentRank > 0) {
      borderColor = Colors.yellow;
    } else {
      borderColor = Colors.grey;
    }

    return Tooltip(
      message: tooltipMessage,
      child:
          Image.asset(
                imagePath,
                width: width,
                height: width,
                fit: BoxFit.cover,
                color: imageColor,
                colorBlendMode: BlendMode.saturation,
                errorBuilder: (context, error, stack) =>
                    const Icon(Icons.error),
              )
              .container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor, width: 2.0),
                  borderRadius: BorderRadius.circular(8.0),
                ),
              )
              .gestureDetector(
                onTap: enabled ? () => buildNotifier.addPoint(talent) : null,
                onLongPress: () {
                  _showTalentDetailSheet(context, ref, talent);
                },
              ),
    );
  }

  Future<void> _showTalentDetailSheet(
    BuildContext context,
    WidgetRef ref,
    Talent talent,
  ) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TalentDetailSheet(talent: talent),
    );
  }
}
