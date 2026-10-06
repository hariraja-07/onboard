<h1 align="center">OnBoard</h1>

<p align="center">
  A local-first, high-speed barcode scanning attendance tracking app for college buses and student transit.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart" alt="Dart" />
  <img src="https://img.shields.io/badge/Database-Drift%20(SQLite)-003B57?logo=sqlite" alt="SQLite" />
  <img src="https://img.shields.io/badge/State_Management-Riverpod-336791" alt="Riverpod" />
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License" />
</p>

## Overview

Managing student bus boarding with paper logs or slow cloud-dependent apps leads to delays, missed departures, and lost records on routes with poor cellular connectivity. **OnBoard** solves this by delivering an ultra-fast, 100% offline-first attendance solution designed specifically for college bus coordinators and transport administrators.

With camera-based barcode scanning, immutable session records, bulk Excel student imports, and instant XLSX report generation, OnBoard turns student check-in into a seamless, verifiable process that never stalls due to network outages.

## Features

- 📷 **Instant Barcode Scanning:** Continuous Code 128 camera scanning powered by `mobile_scanner`, with haptic feedback, duplicate detection, and instant boarding verification. Barcode entry can also be typed by hand when a card is damaged or unreadable.
- 📴 **100% Local-First & Offline:** Backed by an embedded SQLite database via Drift. Zero cloud dependency—attendance works reliably anywhere on the transit route.
- 📋 **Live Attendance Roster:** Real-time visibility into who has boarded and who is missing, with manual toggle override for damaged or forgotten ID cards.
- 🚌 **Trip Management:** Dedicated morning and evening trip sessions with immutable snapshot records preserving student details and timestamps at the moment of scan.
- 📊 **Excel Bulk Import:** Import student directories directly from `.xlsx` spreadsheets with preview validation, column mapping, and duplicate handling.
- 📑 **Automated Report Export:** Generate structured, formatted XLSX attendance logs and summary reports ready for college administration.
- 💾 **Database Backup & Restore:** Built-in local database backup and recovery tools to safeguard historical data across devices.
- 🎨 **Adaptive Material 3 Design:** Edge-to-edge UI with light, dark, and system theme modes calibrated for high contrast and outdoor daylight readability.

## Tech Stack

- **Framework:** Flutter (Material 3)
- **Language:** Dart 3
- **State Management:** Riverpod (`flutter_riverpod`)
- **Database:** Drift (SQLite via `sqlite3_flutter_libs`)
- **Navigation:** `go_router` (Stateful nested routing)
- **Scanner Engine:** `mobile_scanner` (Code 128)
- **Spreadsheet Processing:** `excel_community`
- **File System:** `file_picker`, `path_provider`, `shared_preferences`

## Project Structure

```
lib/
├── core/
│   ├── backup/          # Database backup and restore services
│   ├── database/        # Drift schema, migrations, and four repositories
│   ├── export/          # XLSX report generator and data export service
│   ├── router/          # go_router declarative route definitions
│   ├── theme/           # AppTheme, semantic color scales, spacing tokens
│   ├── utils/           # App-wide constants (app name and version)
│   └── widgets/         # Shared components (loading skeletons)
├── features/
│   ├── attendance/      # Camera scanner, live roster, and attendance controllers
│   ├── dashboard/       # Metric cards, quick actions, and recent session snapshots
│   ├── history/         # Chronological session logs and detailed audit views
│   ├── reports/         # Attendance reports, filtering, and export UI
│   ├── settings/        # Theme switcher, backup/restore, and app preferences
│   └── students/        # Student directory, CRUD, and Excel import
│       └── import/      # Spreadsheet parsing, template, and preview flow
└── main.dart            # App entry point & edge-to-edge system configuration
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) on the **stable** channel (the project pins no Flutter version)
- **Dart 3.11.0 or later** — this is the constraint `pubspec.yaml` actually enforces via `sdk: ^3.11.0`
- Android Studio, VS Code, or Xcode
- Android device or emulator (camera required for live barcode scanning)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/hariraja-07/onboard.git
cd onboard
```

2. Install dependencies:
```bash
flutter pub get
```

3. Generate Drift database code (if modifying tables or queries):
```bash
dart run build_runner build --delete-conflicting-outputs
```

4. Run the app:
```bash
flutter run
```

### Build

To generate a release Android APK:

```bash
flutter build apk --release
```

## Testing

Run the automated test suite, covering unit tests, repository validations, and scenario-based attendance workflows:

```bash
flutter test
```

## Roadmap

- [x] Local-first SQLite database architecture with Drift
- [x] High-speed Code 128 camera check-in
- [x] Live attendance roster with manual overrides
- [x] Excel (.xlsx) student directory bulk import
- [x] XLSX attendance summary report export
- [x] Database backup and restore
- [x] Multi-platform project icon & branding
- [ ] NFC / RFID student card scanning support
- [ ] Optional network export / webhook sync to central college ERP
- [ ] Student profile photo support

## Contributing

1. Fork the repository
2. Create a branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m "Add your feature"`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a pull request

## License

Distributed under the MIT License. See `LICENSE` for details.

## Contact

**Hari Raja** · [GitHub](https://github.com/hariraja-07) · [Repository](https://github.com/hariraja-07/onboard)
