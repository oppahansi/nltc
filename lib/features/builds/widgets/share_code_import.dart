// Flutter Imports
import "package:flutter/material.dart";

// Package Imports
import "package:exui/exui.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

// Project Imports
import "package:ltc/core/navigation/route_paths.dart";
import "package:ltc/core/settings/settings_service_provider.dart";
import "package:ltc/core/talent_build/share_util.dart";
import "package:ltc/core/utils/extensions.dart";
import "package:ltc/core/utils/screen_sizes.dart";
import "package:ltc/core/utils/text_styles.dart";
import "package:ltc/core/widgets/shared.dart";
import "package:ltc/features/calculator/providers/build_state_provider.dart";
import "package:ltc/l10n/app_localizations.dart";

class ShareCodeImport extends ConsumerStatefulWidget {
  const ShareCodeImport({super.key});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _ShareCodeImportState();
}

class _ShareCodeImportState extends ConsumerState<ShareCodeImport> {
  final _importCtrl = TextEditingController();
  final FocusNode _shareCodeFocusNode = FocusNode();
  bool _allowShareCodeFocus = false;
  String? _importError;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _shareCodeFocusNode.skipTraversal = true;
  }

  @override
  void dispose() {
    _shareCodeFocusNode.dispose();
    _importCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowShareCodeFocus && _shareCodeFocusNode.hasFocus) {
      _shareCodeFocusNode.unfocus();
    }
    final settings = ref.watch(settingsProvider).value!;
    final expColor = settings.expColor;
    final loc = AppLocalizations.of(context)!;
    final style = isTablet(context) || isLargeTablet(context)
        ? displaySmall(context)
        : titleLarge(context);

    return [
      loc.import_from_share_code.text(style: style.withColor(expColor)),
      [
            loc.import_build_code.text(
              style: bodySmall(context).withColor(expColor),
            ),
            gapSizeSmall(context).gapColumn,
            TextField(
              controller: _importCtrl,
              focusNode: _shareCodeFocusNode,
              readOnly: !_allowShareCodeFocus,

              onTap: () {
                if (!_allowShareCodeFocus) {
                  setState(() => _allowShareCodeFocus = true);

                  Future.microtask(() {
                    if (mounted) _shareCodeFocusNode.requestFocus();
                  });
                }
              },
              style: bodySmall(context).withColor(expColor),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.black26,
                hintText:
                    "${loc.e_g} tbc-shaman-5530020103-0500315003-500050031",
                hintStyle: bodySmall(context)
                    .withColor(expColor.withAlpha(175)),
                errorText: _importError,
                errorMaxLines: 2,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: expColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: expColor),
                ),
              ),
              onChanged: (_) {
                if (_importError != null) {
                  setState(() => _importError = null);
                }
              },
            ),
            gapSizeSmall(context).gapColumn,
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: expColor,
                foregroundColor: Colors.black,
                minimumSize: const Size(100, 36),
              ),
              onPressed: _importing
                  ? null
                  : () async {
                      final input = classifyShareInput(_importCtrl.text);
                      if (input.error != null) {
                        setState(() {
                          _importError = switch (input.error!) {
                            ShareInputError.empty => loc.import_empty,
                            ShareInputError.invalidFormat =>
                              "${loc.invalid_format} (exp-class-tree1-tree2-tree3)",
                          };
                        });
                        return;
                      }

                      setState(() {
                        _importing = true;
                        _importError = null;
                      });

                      final ok = await ref
                          .read(buildStateProvider.notifier)
                          .importFromShareCode(input.code!);

                      if (!mounted) return;
                      setState(() => _importing = false);

                      if (!ok) {
                        setState(
                          () => _importError = loc.failed_to_import_build,
                        );
                        return;
                      }

                      if (context.mounted) {
                        context.showSnackBar(
                          SnackBar(content: loc.build_imported.text()),
                        );
                        context.pushNamed(RoutePaths.calculator);
                      }
                    },
              child: _importing
                  ? CircularProgressIndicator(strokeWidth: 2).sizedBox(
                      width: gapSizeLarge(context),
                      height: gapSizeLarge(context),
                    )
                  : loc.import.capitalize().text(),
            ).sizedHeight(gapSizeLarge(context)).alignCenterRight(),
          ]
          .columnCrossStart()
          .paddingHorizontal(gapSize(context))
          .container(
            padding: const EdgeInsets.all(8),
            decoration: getDefaultBoxDecoration(expColor),
          ),
    ].column();
  }
}
