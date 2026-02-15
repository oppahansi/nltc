## Overview

**LTC (Talent Calculator)** is a cross-platform Flutter application for planning World of Warcraft character talent builds across multiple expansions (Vanilla, TBC, WotLK). The app features an interactive talent tree calculator, build sharing via codes and Wowhead URLs, local persistence, and character build imports from Battle.net.

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

- **Battle.net Integration** *(Vanilla Classic Anniversary only)*
  - Fetch character builds directly from Battle.net API
  - View active specializations and talent allocations
  - Region and realm selection (US, EU, Korea, Taiwan)
  - *Note: This feature is currently limited to Vanilla Anniversary Realms and may require updates for TBC/WotLK support*

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
- **Networking**: http package for Battle.net API integration
- **Icons**: material_symbols_icons
- **Code Generation**: build_runner, riverpod_generator
- **UI Components**: exui (custom extension library)

## Backend Server Requirement

The Battle.net character import feature requires a backend server to handle OAuth token management and API proxying. This service:

- Obtains Battle.net OAuth tokens using client credentials
- Proxies character profile and specialization requests to avoid CORS issues
- Caches tokens for performance

### Current Status
This feature currently works only for **Vanilla Classic Anniversary** realms. Support for TBC and WotLK expansions needs to be implemented by:
- Updating the namespace parameters for TBC/WotLK classic versions
- Validating API response formats for different expansions
- Testing against live Battle.net endpoints

### Configuration
The app expects the backend server to be accessible via:
- **Local Debug**: `http://10.0.2.2:8080` (Android) or `http://localhost:8080` (iOS)
- **Release**: Remote host configured via environment variables
- Server repo: https://github.com/oppahansi/ltcbackend

Set these environment variables during build if using a custom backend:
```
LOCAL_TOKEN_HOST=your.local.host
REMOTE_TOKEN_HOST=your.remote.host
```

See [`lib/features/builds/services/battlenet_service.dart`](lib/features/builds/services/battlenet_service.dart) for implementation details.

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
│   ├── builds/              # Battle.net character builds feature
│   ├── calculator/          # Talent calculator feature
│   ├── home/                # Home screen and navigation
│   └── settings/            # User preferences
├── l10n/                    # Localization (generated)
└── main.dart                # App entry point
```

## Getting Started

### Prerequisites
- Flutter 3.13+ (check `pubspec.yaml`)
- iOS 11.0+, Android 21+
- https://github.com/oppahansi/ltcbackend
  - Backend service to fetch battle.net character builds
  - Probably outdated, worked for Classic Vanilla Anniversary


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