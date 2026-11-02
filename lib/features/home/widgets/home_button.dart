// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";

class HomeButton extends ConsumerWidget {
  final String path;
  final String title;
  final IconData icon;
  final VoidCallback? onTap;

  const HomeButton({
    super.key,
    required this.path,
    required this.title,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).value!;
    final expColor = settings.expColor;
    final classColor = settings.classColor;
    final style = isTablet(context) || isLargeTablet(context)
        ? displaySmall(context).withColor(classColor)
        : titleLarge(context).withColor(classColor);

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black.withAlpha(150),
        foregroundColor: expColor,
        side: BorderSide(color: expColor),
        padding: EdgeInsets.symmetric(
          vertical: gapSize(context) * 0.75,
          horizontal: gapSize(context),
        ),
      ),
      onPressed: () {
        if (onTap != null) {
          onTap!();
        }

        context.pushNamed(path);
      },
      child:
          [
            gapSize(context).gapRow,
            icon.icon(color: expColor, size: gapSize(context) * 1.5),
            gapSize(context).gapRow,
            title.text(style: style),
            gapSize(context).gapRow,
          ].row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            mainAxisSize: MainAxisSize.min,
          ),
    ).sizedWidth(screenWidth(context, 0.75));
  }
}
