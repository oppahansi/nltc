# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Riverpod codegen: `dart run build_runner build` (the README's `flutter pub run` form is outdated)
- Localizations: edit `lib/l10n/app_en.arb` and `app_de.arb`, then run `flutter gen-l10n`. Ignore the `flutter_intl` block in `pubspec.yaml`.
- Lint: `flutter analyze` (also runs `riverpod_lint`, enabled as an analyzer plugin in `analysis_options.yaml`).

Tests: `flutter test`. `test/helpers/test_db.dart` gives a test its own first-install copy of the bundled DBs. Coverage is still thin, so also run the app to verify UI changes.

## Architecture

Feature-first: `lib/features/<feature>/` holds a feature's screen, widgets, providers and logic, and `lib/core/` holds what several features share. `lib/app/` is the only place that imports every screen; navigate with `RoutePaths`. `test/architecture_test.dart` enforces the allowed dependencies, so change its tables deliberately rather than working around them. Code moves to `core/` only when a second feature needs it.

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
- Data DB: installs replace their copy whenever its version differs. After changing the data, bump `dataDbVersion` in `lib/core/db/db_constants.dart` and `PRAGMA user_version` in the SQL; a test enforces this.
- User DB: holds the user's builds and is never replaced. A schema change needs a step in `lib/core/db/migrations.dart`, a bump of `userDbVersion` and the SQL's `PRAGMA user_version`, and the change in the bundled SQL too.
- Saved builds refer to talent ids, so never change an existing talent's id.

To check bundled data against game clients, see `tool/README.md`.

## Battle.net import

Removed along with its `ltcbackend` dependency. It will be revisited later; restore it from git history when that happens.

## Git

Commit directly to `main`, using scoped conventional commits: `type(scope): summary`, e.g. `fix(calculator): stop double-counting points on load`.

## Game editions

The app targets three editions: Original (the clients from back then: vanilla, tbc, wotlk), Classic (today's re-releases: vanilla, tbc, wotlk) and Forever (standalone, not split into those expansions). Only compare data against a client from the same edition. Work order: Original first, then Classic, then Forever. The existing bundled data is Original. Forever has its own unrelated "Legacy" talent system.
