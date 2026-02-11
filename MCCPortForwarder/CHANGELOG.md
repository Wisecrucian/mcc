# Changelog

All notable changes to MCC Port Forwarder will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Global keyboard shortcut to toggle popover
- Connection health checks (ping endpoint)
- Process output viewer in UI
- Auto-reconnect on failure
- Export/Import configuration
- Dark mode icon variants
- Recent connections quick access

---

## [1.0.0] - 2026-01-23

### Added
- Initial release
- Status bar application for macOS 13.0+
- Service and host management
- Process lifecycle management (start/stop)
- Real-time status tracking (running/stopped/error)
- Bulk operations (Start All / Stop All)
- UserDefaults persistence
- MVVM architecture
- SwiftUI + AppKit integration
- Graceful process termination (SIGTERM → SIGKILL)
- Concurrent process management with thread safety
- State polling (1-second interval)

### Architecture
- **Models**: Service, Host, ProcessState
- **Services**: ProcessService (CLI management), StorageService (persistence)
- **ViewModels**: AppViewModel (state + actions)
- **Views**: ContentView, ServiceRowView, HostRowView
- **App**: AppDelegate (status bar), MCCPortForwarderApp (entry)

### Documentation
- README.md - Project overview
- ARCHITECTURE.md - Technical deep dive
- DEPLOYMENT.md - Release guide
- TROUBLESHOOTING.md - Debug guide
- QUICKSTART.md - User guide

### Developer Experience
- XcodeGen project generation
- Makefile for common tasks
- Setup script with dependency checks
- Comprehensive inline code comments

### Known Limitations
- Hardcoded binary path: `/usr/local/bin/mcc`
- No process output viewing (console only)
- No connection health checks
- No automatic reconnect
- Manual host management (no discovery)

---

## Release Notes Template

### [X.Y.Z] - YYYY-MM-DD

#### Added
- New features

#### Changed
- Changes to existing functionality

#### Deprecated
- Soon-to-be removed features

#### Removed
- Removed features

#### Fixed
- Bug fixes

#### Security
- Security fixes

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2026-01-23 | Initial release |

---

## Upgrade Guide

### From 0.x to 1.0.0

First release - no upgrade needed.

---

## Breaking Changes

### 1.0.0

None - initial release.

---

## Deprecation Notices

None at this time.

---

## Security Updates

None at this time.

