// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";

class ExpansionChip extends ConsumerWidget {
  final String label;
  final String iconAsset;
  final bool selected;
  final VoidCallback onTap;

  const ExpansionChip({
    super.key,
    required this.label,
    required this.iconAsset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final expColor = selected ? settings.expColor : Colors.grey;
    final style = isTablet(context) || isLargeTablet(context)
        ? titleLarge(context).withColor(expColor)
        : bodyMedium(context).withColor(expColor);

    return [
      Image.asset(
        iconAsset,
        width: screenWidth(context, .2),
        height: screenWidth(context, .2),
        color: selected ? null : Colors.black.withAlpha(150),
        colorBlendMode: selected ? null : BlendMode.srcATop,
      ),
      gapSizeSmall(context).gapColumn,
      label.text(style: style),
    ].column().gestureDetector(onTap: onTap);
  }
}
