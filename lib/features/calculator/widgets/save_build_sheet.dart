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
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/l10n/app_localizations.dart";

class SaveBuildSheet extends ConsumerStatefulWidget {
  const SaveBuildSheet({super.key});

  @override
  ConsumerState<SaveBuildSheet> createState() => _SaveBuildSheetState();
}

class _SaveBuildSheetState extends ConsumerState<SaveBuildSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(buildStateProvider).value!.suggestedTitle,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final loc = AppLocalizations.of(context)!;
    final title = _controller.text.trim();
    if (title.isEmpty) {
      context.showSnackBar(SnackBar(content: loc.invalid_title.text()));
      return;
    }

    context.pop(title);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value!;
    final loc = AppLocalizations.of(context)!;

    final expColor = settings.expColor;
    final classColor = settings.classColor;

    return [
          loc.save_build.text(
            style: headlineMedium(context)
                .withColor(classColor)
                .withWeight(FontWeight.bold),
          ),
          gapSize(context).gapColumn,
          TextField(
            controller: _controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            style: bodyLarge(context).withColor(classColor),
            decoration: InputDecoration(
              labelText: loc.build_title,
              labelStyle: bodyMedium(context).withColor(classColor),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white38),
              ),
              floatingLabelStyle: bodyMedium(context).withColor(classColor),
              fillColor: Colors.black.withAlpha(50),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: classColor),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          gapSize(context).gapColumn,
          [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white38),
                textStyle: bodyLarge(context).withColor(Colors.white),
              ),
              onPressed: () => context.pop(),
              child: loc.cancel.capitalize().text(
                style: bodyLarge(context).withColor(Colors.white),
              ),
            ).expanded1,
            gapSize(context).gapRow,
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: expColor,
                disabledBackgroundColor: Colors.grey[700],
                textStyle: bodyLarge(context)
                    .withColor(Colors.black)
                    .withWeight(FontWeight.bold),
              ),
              onPressed: _submit,
              child: loc.save.capitalize().text(
                style: bodyLarge(context).withColor(Colors.black),
              ),
            ).expanded1,
          ].row(),
        ]
        .column(mainAxisSize: MainAxisSize.min)
        .padding(
          EdgeInsets.only(
            left: gapSize(context),
            right: gapSize(context),
            top: gapSize(context),
            bottom: MediaQuery.of(context).viewInsets.bottom + gapSize(context),
          ),
        );
  }
}
