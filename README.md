## Overview

**LTC (Talent Calculator)** is a cross-platform Flutter application for planning World of Warcraft character talent builds across multiple expansions (Vanilla, TBC, WotLK). The app features an interactive talent tree calculator, build sharing via codes and Wowhead URLs, and local persistence.

This is a complete, production-ready Flutter project demonstrating modern app architecture with state management (Riverpod), localization, native platform integration, and a local SQLite database.

## Features

- **Talent Calculator**
  - Interactive talent tree UI with point allocation and undo functionality
  - Support for Vanilla, TBC, and WotLK expansions
  - Build order tracking with sequence visualization
  - Real-time validation (row gating, dependencies, max points)

- **Build Management**
  - Save builds locally with custom titles
  - Auto-localizing titles when switching languages
  - Delete and manage saved builds
  
- **Build Sharing**
  - Export builds as compact share codes (`exp-class-tree1-tree2-tree3`)
  - Generate Wowhead talent calculator URLs (TBC & WotLK)
  - Import builds from share codes or Wowhead links

- **Localization**
  - Full German and English support
  - Language switching with automatic title re-localization

- **Data Management**
  - Export/Import database backups via native file pickers (iOS & Android)
  - Local SQLite database with versioned migrations
  - Asset-embedded reference data (expansions, classes, talents)

- **User Experience**
  - Interactive tutorial system
  - Dark theme UI with expansion-specific color schemes
  - Responsive design (phone and tablet optimized)
  - Settings for build order display and language preferences

## Screenshots

<img src="assets/nltc1.png" alt="Talent Calculator" width="300" />
<img src="assets/nltc2.png" alt="Build Management" width="300" />

## Tech Stack

- **Framework**: Flutter, Material 3
- **State Management**: Riverpod with Riverpod Annotations (code generation)
- **Localization**: flutter_localizations, intl (ARB-based strings)
- **Persistence**: SQLite via sqflite with versioned migrations
- **Icons**: material_symbols_icons
- **Code Generation**: build_runner, riverpod_generator
- **UI Components**: exui (custom extension library)

## Project Structure

```
lib/
├── core/                    # Shared utilities and services
│   ├── db/                  # SQLite database setup
│   ├── models/              # Data entities
│   ├── providers/           # Global Riverpod providers
│   ├── repos/               # Data repository layer
│   ├── services/            # Native integration (backup/restore)
│   └── utils/               # Constants, extensions, helpers
├── features/                # Feature-specific code
│   ├── builds/              # Saved builds and share code import
│   ├── calculator/          # Talent calculator feature
│   ├── home/                # Home screen and navigation
│   └── settings/            # User preferences
├── l10n/                    # Localization (generated)
└── main.dart                # App entry point
```

## Getting Started

### Prerequisites
- Flutter 3.47+ (check `pubspec.yaml`)
- iOS 15.0+


### Installation

```bash
# Install dependencies
flutter pub get

# Generate code (Riverpod, localization, etc.)
flutter pub run build_runner build

# Run the app
flutter run
```

### Building for Release

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Development Notes

- **Code Generation**: Run `flutter pub run build_runner watch` during development
- **Database Migrations**: Asset database at `assets/db/ltc_data.db` contains talent trees, classes, and expansions
- **Localization**: Edit ARB files in `lib/l10n/` and regenerate with `flutter gen-l10n`
- **Linting**: Configured via `analysis_options.yaml` for strict static analysis

## License

Licensed under the MIT License. See [LICENSE](LICENSE) for details.