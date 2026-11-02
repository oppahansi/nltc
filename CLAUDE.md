# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Riverpod codegen: `dart run build_runner build` (the README's `flutter pub run` form is outdated)
- Localizations: edit `lib/l10n/app_en.arb` and `app_de.arb`, then run `flutter gen-l10n`. Ignore the `flutter_intl` block in `pubspec.yaml`.
- Lint: `flutter analyze`. `riverpod_lint` is not enabled as an analyzer plugin, so run it with `dart run custom_lint`.

There are no tests (`test/` does not exist), so verify changes with `flutter analyze` and by running the app.

## Generated code

`*.g.dart` and `lib/l10n/app_localizations*.dart` are committed. Never edit them by hand. After changing a provider or an ARB file, regenerate and commit the output with the source change.

## Code style

- Use `package:ltc/...` imports, never relative ones (`always_use_package_imports`). The package is named `ltc`, not `nltc`.
- Group imports under the comments `// Dart Imports`, `// Flutter Imports`, `// Package Imports`, `// Project Imports`.
- Use double quotes for strings.
- Define providers with `@Riverpod` codegen, not hand-written providers.
- Add every user-facing string to both ARB files (en and de).

## Bundled databases

- `assets/db/*.db.sql` are the source of truth. Edit the SQL, then rebuild the `.db` with `/rebuild-db`. Never edit a `.db` directly.
- The app copies a bundled DB only if the file is not already on the device (`lib/core/db/db.dart`), so rebuilt DBs do not reach existing installs. Those need a migration in `lib/core/db/migrations.dart` and a `dbVersion` bump.

## Battle.net import

The Battle.net integration and its backend are due to be revisited. Don't rely on the README's setup steps: it shows shell env vars, but `battlenet_service.dart` reads `String.fromEnvironment`, which only sees `--dart-define` values.

## Git

Commit directly to `main`, using scoped conventional commits: `type(scope): summary`, e.g. `fix(calculator): stop double-counting points on load`.

## Game editions

The app targets three editions: Legacy (original clients: vanilla, tbc, wotlk), Classic (today's re-releases: vanilla, tbc, wotlk) and Forever (standalone, not split into those expansions). Only compare data against a client from the same edition. The existing bundled data targets Legacy and may contain mistakes.
