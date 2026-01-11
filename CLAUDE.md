# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Printernizer iOS is a companion app for the Printernizer 3D printer monitoring system. It provides full feature parity with the web app, allowing users to monitor and control their 3D printers on local network.

**Key Features:**
- Real-time printer monitoring with temperature display
- Camera preview with auto-refresh and snapshot gallery
- Print job history with filtering and details
- File management with thumbnails
- Materials inventory tracking
- WebSocket support for live updates

## Build Commands

```bash
# Build the project
xcodebuild -scheme Printernizer -configuration Debug build

# Run all tests
xcodebuild -scheme Printernizer -configuration Debug test

# Run a single test class
xcodebuild -scheme Printernizer -only-testing:PrinternizerTests/PrinterTests test

# Run a single test method
xcodebuild -scheme Printernizer -only-testing:PrinternizerTests/PrinterTests/testPrinterStatusDisplayName test

# Build for release
xcodebuild -scheme Printernizer -configuration Release build
```

## Architecture

SwiftUI + MVVM with the following structure:

```
Printernizer/Sources/
├── App/                  # App entry point (PrinternizerApp, ContentView)
├── Models/               # Data models (Printer, PrintJob)
├── Views/
│   ├── Camera/           # Camera preview and snapshots
│   ├── Components/       # Reusable UI components
│   ├── Files/            # File list and detail views
│   ├── Jobs/             # Job history views
│   ├── Materials/        # Materials inventory views
│   ├── Printer/          # Printer list and detail views
│   └── Settings/         # App settings
├── ViewModels/           # @MainActor observable view models
└── Services/             # API, WebSocket, and domain services
```

## Key Patterns

- **ViewModels** are `@MainActor` classes using `@Published` properties
- **APIService** is passed via `@EnvironmentObject` from the app root
- **Domain Services** (CameraService, JobService, FileService, MaterialService) are instantiated per-view
- **Models** conform to `Identifiable`, `Codable`, and `Equatable`
- **Preview data** is provided via static `.preview` properties on models
- **Async/await** used throughout for API calls
- **JSON encoding** uses snake_case conversion for backend compatibility

## Services

| Service | Purpose |
|---------|---------|
| `APIService` | Core REST API for printers (list, details, controls) |
| `WebSocketService` | Real-time updates (printer_status, job_update, system_event) |
| `CameraService` | Camera preview, snapshots |
| `JobService` | Print job history, filtering, cancellation |
| `FileService` | File listing, thumbnails, deletion |
| `MaterialService` | Materials inventory, stats |

## Main Navigation

ContentView uses TabView with 5 tabs:
1. **Printers** - PrinterListView
2. **Jobs** - JobListView
3. **Files** - FileListView
4. **Materials** - MaterialListView
5. **Settings** - SettingsView

## Backend API

The app connects to a Printernizer backend (FastAPI) on local network:
- Base URL stored in `@AppStorage("serverURL")`
- REST endpoints: `/api/v1/printers/`, `/api/v1/jobs/`, `/api/v1/files/`, `/api/v1/materials/`
- WebSocket: `/api/v1/ws`

## Configuration

- Server URL stored in `@AppStorage("serverURL")`
- Refresh interval stored in `@AppStorage("refreshInterval")`
- Bundle identifier: `com.printernizer.ios`
- Minimum deployment target: iOS 17.0

## CI/CD

GitHub Actions workflow (`.github/workflows/ci.yml`):
- Builds on macOS 14 with Xcode 15.2
- Runs tests on iOS 17 simulator
- SwiftLint for code style
- Test results uploaded as artifacts

## Future Features

- Push notifications (requires backend changes)
- QR code setup (scan from web app)
- Remote access (requires authentication)
- Share Sheet for 3D print files
