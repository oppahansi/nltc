# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Riverpod codegen: `dart run build_runner build` (the README's `flutter pub run` form is outdated)
- Localizations: edit `lib/l10n/app_en.arb` and `app_de.arb`, then run `flutter gen-l10n`. Ignore the `flutter_intl` block in `pubspec.yaml`.
- Lint: `flutter analyze` (also runs `riverpod_lint`, enabled as an analyzer plugin in `analysis_options.yaml`).

Tests: `flutter test`. `test/helpers/test_db.dart` gives a test its own first-install copy of the bundled DBs. Coverage is still thin, so also run the app to verify UI changes.

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

Removed along with its `ltcbackend` dependency. It will be revisited later; restore it from git history when that happens.

## Git

Commit directly to `main`, using scoped conventional commits: `type(scope): summary`, e.g. `fix(calculator): stop double-counting points on load`.

## Game editions

The app targets three editions: Legacy (original clients: vanilla, tbc, wotlk), Classic (today's re-releases: vanilla, tbc, wotlk) and Forever (standalone, not split into those expansions). Only compare data against a client from the same edition. The existing bundled data targets Legacy and may contain mistakes.
