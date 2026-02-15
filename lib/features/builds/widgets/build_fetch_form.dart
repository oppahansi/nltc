// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:material_symbols_icons/symbols.dart";

// Project Imports
import "package:ltc/core/providers/settings_service_provider.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/widgets/shared.dart";
import "package:ltc/features/builds/providers/builds_providers.dart";
import "package:ltc/features/builds/widgets/region_realm_selector.dart";
import "package:ltc/features/builds/widgets/remote_build_list.dart";
import "package:ltc/l10n/app_localizations.dart";

class BuildFetchForm extends ConsumerStatefulWidget {
  const BuildFetchForm({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _BuildFetchFormState();
}

class _BuildFetchFormState extends ConsumerState<BuildFetchForm> {
  final _charNameController = TextEditingController();

  final FocusNode _charNameFocusNode = FocusNode();
  bool _allowCharNameFocus = false;

  @override
  void initState() {
    super.initState();
    _charNameFocusNode.skipTraversal = true;
  }

  @override
  void dispose() {
    _charNameFocusNode.dispose();
    _charNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowCharNameFocus && _charNameFocusNode.hasFocus) {
      _charNameFocusNode.unfocus();
    }

    final selectedRealm = ref.watch(selectedRealmProvider);
    final settings = ref.watch(settingsProvider).value!;
    final expColor = settings.expColor;
    final loc = AppLocalizations.of(context)!;
    final buildsAsync = ref.watch(remoteClassBuildsProvider);

    final charNameInputField = TextFormField(
      focusNode: _charNameFocusNode,
      readOnly: !_allowCharNameFocus,
      enableInteractiveSelection: true,
      autofocus: false,
      onTap: () {
        if (!_allowCharNameFocus) {
          setState(() {
            _allowCharNameFocus = true;
          });
          Future.microtask(() {
            if (mounted) _charNameFocusNode.requestFocus();
          });
        }
      },
      style: bodyMedium(context).withColor(expColor),
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: loc.character_name,
        labelStyle: bodyMedium(context).withColor(expColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: expColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: expColor),
        ),
      ),
      cursorColor: expColor,
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? loc.required.capitalize() : null,
      controller: _charNameController,
    );

    final loadBuildsButton = ElevatedButton.icon(
      icon: Symbols.cloud_download.icon(size: gapSize(context)),
      style: ElevatedButton.styleFrom(
        backgroundColor: expColor,
        foregroundColor: Colors.black,
        disabledBackgroundColor: expColor.withAlpha(100),
        disabledForegroundColor: Colors.black,
      ),
      onPressed:
          selectedRealm == null ||
              selectedRealm.isEmpty ||
              buildsAsync.isLoading
          ? null
          : () async {
              FocusScope.of(context).unfocus();

              setState(() {
                _allowCharNameFocus = false;
              });

              final charName = _charNameController.text.trim();
              ref.read(selectedCharNameProvider.notifier).setName(charName);

              await ref.read(remoteClassBuildsProvider.notifier).refresh();
            },
      label: buildsAsync.isLoading
          ? "${loc.loading.capitalize()}...".text()
          : loc.load_builds.text(),
    ).sizedBox(height: gapSizeLarge(context)).alignCenterRight();

    return [
      loc.character_builds.text(style: titleLarge(context).withColor(expColor)),
      loc.vanilla_only.text(style: titleSmall(context).withColor(expColor)),
      Form(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gapSize(context)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              gapSize(context).gapColumn,
              const RegionRealmSelector(),
              gapSize(context).gapColumn,
              charNameInputField,
              gapSize(context).gapColumn,
              loadBuildsButton,
              gapSize(context).gapColumn,
              const RemoteBuildsList(),
            ],
          ),
        ).container(decoration: getDefaultBoxDecoration(expColor)),
      ),
    ].column();
  }
}
