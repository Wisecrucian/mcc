# Changelog

All notable changes to MCC Port Forwarder will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.1.1] - 2026-08-21

### Added
- **Paste-to-parse instances**: in Add/Edit Host, paste one or more real instance identifiers
  (e.g. `2.myservice.dc1`) and hit Parse — the leading number becomes the instance number, and
  whichever segment matches a configured datacenter fills in that datacenter, its instance
  list, and its local ports automatically.
- **Instance version lookup**: locations added by pasting a real instance name get a version
  badge next to their port row, fetched via `mcc tool_status -t instance <name>` (once on add,
  or manually by tapping the badge). Off by default — enable it in Settings ("Instance Version
  Lookup").

## [1.1.0] - 2026-08-21

### Added
- **Per-datacenter instance count**: each selected datacenter can now fan out into multiple
  instances, each with its own local port and hostname via a new `{instance}` placeholder
  (alongside `{location}`) in the hostname template. Port rows show an "instance N" badge
  when a datacenter has more than one.

### Fixed
- Retries no longer continue after pressing Stop while a connection is in its retry-delay
  window (the manual-stop flag wasn't being recorded during that window, so the pending
  retry silently reconnected anyway).
- Replaced deprecated APIs (`NSApplication.activate(ignoringOtherApps:)`,
  `String(contentsOfFile:encoding:)`) and resolved several Swift 6 strict-concurrency
  errors, for compatibility with newer Xcode/macOS toolchains.

## [1.0.0] - 2026-02-11

### 🎉 Initial Release

#### Core Features
- **Service & Host Management**: Hierarchical service/host structure with multiple port mappings per host
- **Multi-Datacenter Support**: Configure multiple datacenters and assign different local ports per location
- **Real-time Status Tracking**: 9 detailed connection states with automatic detection from logs
- **Configuration Import/Export**: Backup and restore complete configuration in JSON format
- **Process Management**: Start/stop ports individually or in bulk, kill blocking processes
- **Auto-Retry**: Configurable retry attempts and delays for failed connections
- **Authentication**: Login/Logout commands with browser redirect support

#### Status System
- 🔵 **Connecting** - Process started, waiting for connection
- 🟡 **Authenticating** - Authentication in progress
- 🟢 **Ready** - Connection established (detected from "Proxying connections to...")
- 🔴 **Error** - Connection failed
- 🟠 **Timeout** - Connection timeout exceeded
- 🟠 **Port Busy** - Local port already in use
- 🔄 **Restarting** - Auto-retry in progress
- 🟣 **Disconnected** - Connection was established but dropped
- ⚪ **Stopped** - Not running

#### Port Management
- **Multiple Ports per Host**: Each host can have multiple port mappings
- **Independent Processes**: Each port runs as separate process
- **Kill Blocking Processes**: Graceful SIGTERM → force SIGKILL after 2s
- **Port Status Updates**: Automatic status change after killing blocking process

#### Datacenter Management
- **Hostname Templates**: Use `{location}` placeholder (e.g., `db.{location}.example.com`)
- **Per-Location Ports**: Different local ports for same service in different datacenters
- **Visual Tags**: Color-coded datacenter tags for easy identification
- **Flexible Configuration**: Add/remove datacenters in settings

#### Configuration Management
- **Export Configuration**: Save all services, hosts, ports, and settings to JSON
- **Import Configuration**: Restore configuration from JSON (replaces existing)
- **UUID-Free Export**: Clean JSON format without internal IDs
- **Auto-UUID Generation**: New UUIDs generated on import
- **Test Files Included**: Sample configurations for testing

#### Logging
- **Per-Port Logs**: Separate logs for each port mapping
- **Application Logs**: Global application activity log
- **Copy Functionality**: Copy individual logs or all logs to clipboard
- **Text Selection**: Select and copy log text manually
- **Real-time Updates**: Live log streaming from running processes

#### Settings
- **Customizable Commands**: Configure port forward, login, and logout commands
- **PATH Environment**: Application automatically uses shell PATH
- **Retry Configuration**: Max attempts (1-20), delay (1-60s)
- **Datacenter Management**: Add/remove datacenters
- **Reset to Defaults**: One-click reset all settings
- **Version Display**: About section with version information

#### User Interface
- **Clean macOS Design**: Native SwiftUI interface
- **Status Indicators**: Color-coded status circles with emoji
- **Expandable Services**: Show/hide child services and hosts
- **Scrollable Content**: Proper scrolling with preserved action buttons
- **Aggregated States**: Services show worst state of all ports
- **Active Connection Counter**: Shows only Ready connections

#### Version System
- **Version File**: `build.number` stores current version
- **In-App Display**: Version visible in Settings → About
- **Versioned Archives**: Distribution files include version (e.g., `MCCPortForwarder-v1.0.0.zip`)
- **Makefile Integration**: Automatic version reading and usage

#### Architecture
- **MVVM Pattern**: Clean separation of concerns
- **SwiftUI + AppKit**: Modern UI with system integration
- **Concurrent Processing**: Thread-safe process management
- **Persistent Storage**: UserDefaults for configuration
- **Service Layer**: Modular services for different responsibilities

#### Developer Experience
- **XcodeGen**: Project generation from YAML
- **Makefile**: Common tasks (build, run, clean, dist)
- **Setup Script**: Dependency checking
- **Git Integration**: Proper .gitignore and repository structure

### Technical Details

#### Services
- `AppViewModel` - Main view model orchestrating all operations
- `ProcessService` - CLI process management with output capture
- `StorageService` - Configuration persistence
- `SettingsService` - Application settings management
- `LogService` - Per-port log storage
- `AppLogService` - Application-wide logging
- `PortKillerService` - Process termination utilities
- `VersionService` - Version management

#### Models
- `Service` - Hierarchical service with child services
- `Host` - Host with multiple port mappings and datacenter support
- `PortMapping` - Port forwarding configuration
- `LocationMapping` - Datacenter-specific configuration
- `ProcessState` - Connection state enumeration
- `ConfigurationExport` - Import/export data structures

#### Build System
- **Minimum macOS**: 13.0+
- **Swift**: 5.9
- **Dependencies**: None (pure SwiftUI)
- **Build Tool**: Xcode 15.2+
- **Distribution**: Standalone .app bundle

### Known Limitations
- No automatic reconnection on disconnect (manual restart required)
- No connection health checks
- No process output viewer (logs only)
- No keyboard shortcuts
- No dark mode icon variants

### Documentation
- `README.md` - Project overview and quick start
- `ARCHITECTURE.md` - Technical deep dive
- `DEPLOYMENT.md` - Release and distribution guide
- `DISTRIBUTION.md` - User installation instructions
- `USER_GUIDE.md` - End-user documentation
- `TROUBLESHOOTING.md` - Common issues and solutions
- `QUICKSTART.md` - Getting started guide
- `PROJECT_SUMMARY.md` - Comprehensive project summary

---

## Future Plans

### Planned Features
- Global keyboard shortcut to toggle window
- Connection health checks (ping endpoint)
- Auto-reconnect on disconnect
- Recent connections quick access
- Export/Import individual services
- Connection history and statistics
- Custom status bar icon states
- Notification system for connection changes

### Potential Improvements
- Search/filter services and hosts
- Bulk edit operations
- Connection groups/profiles
- SSH tunnel support
- SOCKS proxy support
- Custom log filters
- Export logs to file

---

## Version History

| Version | Date | Description |
|---------|------|-------------|
| 1.0.0 | 2026-02-11 | Initial release with full feature set |

---

## Upgrade Guide

### First Installation

1. Download `MCCPortForwarder-v1.0.0.zip`
2. Extract and copy `MCCPortForwarder.app` to `/Applications/`
3. Right-click and select "Open" on first launch (bypass Gatekeeper)
4. Configure commands in Settings
5. Add your services and hosts

---

## Credits

Built with ❤️ using SwiftUI and macOS native technologies.

---

## License

See LICENSE file for details.
