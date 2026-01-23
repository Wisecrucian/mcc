# Deployment Guide

## Development Build

### Quick Start

```bash
cd MCCPortForwarder
make setup    # Generate Xcode project (first time only)
make run      # Build and run
```

### Xcode

```bash
open MCCPortForwarder.xcodeproj
# Select MCCPortForwarder scheme
# ⌘ + R to run
```

App appears in status bar immediately.

---

## Release Build

### 1. Code Signing

**Option A: Developer ID** (recommended for distribution)

```bash
# In Xcode:
# Target → Signing & Capabilities
# Team: [Your Team]
# Signing Certificate: Developer ID Application
```

**Option B: Ad-Hoc** (testing only)

```yaml
# project.yml
CODE_SIGN_IDENTITY: "-"
CODE_SIGN_STYLE: Manual
```

### 2. Build Release

```bash
make build
```

Or via Xcode:
- Product → Archive
- Distribute App → Copy App

### 3. Install

```bash
make install
# Installs to /Applications/MCCPortForwarder.app
```

Or manually:
```bash
cp -R ~/Library/Developer/Xcode/DerivedData/.../Release/MCCPortForwarder.app \
   /Applications/
```

---

## Notarization (macOS 10.15+)

Required for distribution outside App Store.

### Prerequisites

- Apple Developer Account ($99/year)
- Developer ID certificate
- App-specific password

### Steps

**1. Enable Hardened Runtime**

```yaml
# project.yml
ENABLE_HARDENED_RUNTIME: YES
```

**2. Create entitlements**

```xml
<!-- MCCPortForwarder/MCCPortForwarder.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
</dict>
</plist>
```

**3. Build and sign**

```bash
xcodebuild -project MCCPortForwarder.xcodeproj \
  -scheme MCCPortForwarder \
  -configuration Release \
  -archivePath MCCPortForwarder.xcarchive \
  archive

xcodebuild -exportArchive \
  -archivePath MCCPortForwarder.xcarchive \
  -exportPath ./Export \
  -exportOptionsPlist ExportOptions.plist
```

**4. Submit for notarization**

```bash
# Store credentials
xcrun notarytool store-credentials "MCCProfile" \
  --apple-id "your@email.com" \
  --team-id "TEAM_ID"

# Submit
xcrun notarytool submit MCCPortForwarder.app.zip \
  --keychain-profile "MCCProfile" \
  --wait

# Staple ticket
xcrun stapler staple MCCPortForwarder.app
```

---

## Distribution

### DMG Creation

**Manual (Disk Utility)**:
1. Open Disk Utility
2. File → New Image → Image from Folder
3. Select MCCPortForwarder.app
4. Format: compressed
5. Save as MCCPortForwarder-1.0.0.dmg

**Automated (create-dmg)**:

```bash
brew install create-dmg

create-dmg \
  --volname "MCC Port Forwarder" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "MCCPortForwarder.app" 175 120 \
  --hide-extension "MCCPortForwarder.app" \
  --app-drop-link 425 120 \
  "MCCPortForwarder-1.0.0.dmg" \
  "/path/to/MCCPortForwarder.app"
```

### ZIP Archive

```bash
ditto -c -k --keepParent MCCPortForwarder.app MCCPortForwarder-1.0.0.zip
```

---

## Auto-Updater (Sparkle)

### 1. Install Sparkle

```bash
# Download from: https://sparkle-project.org/
# Add Sparkle.framework to project
```

### 2. Configure Info.plist

```xml
<key>SUFeedURL</key>
<string>https://yourdomain.com/appcast.xml</string>
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY</string>
```

### 3. Add update menu

```swift
// AppDelegate.swift
import Sparkle

let updaterController = SPUStandardUpdaterController(
    startingUpdater: true,
    updaterDelegate: nil,
    userDriverDelegate: nil
)
```

### 4. Generate appcast

```bash
./bin/generate_appcast /path/to/releases/
```

### 5. Host appcast.xml

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>MCC Port Forwarder Updates</title>
    <item>
      <title>Version 1.0.0</title>
      <sparkle:version>1.0.0</sparkle:version>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <enclosure url="https://yourdomain.com/MCCPortForwarder-1.0.0.zip"
                 sparkle:edSignature="..."
                 length="..."
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
```

---

## CI/CD

### GitHub Actions

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Xcode
        uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable
      
      - name: Install XcodeGen
        run: brew install xcodegen
      
      - name: Generate project
        run: xcodegen generate
      
      - name: Build
        run: |
          xcodebuild -project MCCPortForwarder.xcodeproj \
            -scheme MCCPortForwarder \
            -configuration Release \
            build
      
      - name: Create DMG
        run: |
          brew install create-dmg
          create-dmg ...
      
      - name: Upload Release
        uses: softprops/action-gh-release@v1
        with:
          files: MCCPortForwarder-*.dmg
```

---

## Configuration Management

### Binary Path Detection

Replace hardcoded path:

```swift
// ProcessService.swift

private func findMCCBinary() -> URL? {
    // Check common locations
    let paths = [
        "/usr/local/bin/mcc",
        "/opt/homebrew/bin/mcc",
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".local/bin/mcc")
    ]
    
    return paths.first { FileManager.default.fileExists(atPath: $0) }
}

func startHost(...) {
    guard let binaryURL = findMCCBinary() else {
        completion(.failure(ProcessError.binaryNotFound))
        return
    }
    
    process.executableURL = binaryURL
    // ...
}
```

### User Preferences

```swift
// Settings.swift
struct AppSettings {
    @AppStorage("mccBinaryPath") var binaryPath = "/usr/local/bin/mcc"
    @AppStorage("autoStartOnLogin") var autoStart = false
    @AppStorage("showNotifications") var notifications = true
}

// In ContentView
@StateObject private var settings = AppSettings()
```

### Login Item

```swift
// AppDelegate.swift
import ServiceManagement

func enableLoginItem() {
    let identifier = "com.mcc.portforwarder.launcher"
    SMLoginItemSetEnabled(identifier as CFString, true)
}
```

---

## Monitoring

### Logging

```swift
import os.log

extension Logger {
    static let process = Logger(
        subsystem: "com.mcc.portforwarder",
        category: "process"
    )
}

// Usage
Logger.process.info("Starting host: \(hostname)")
Logger.process.error("Failed to start: \(error.localizedDescription)")
```

### Crash Reporting

**Sentry**:

```swift
import Sentry

// AppDelegate.applicationDidFinishLaunching
SentrySDK.start { options in
    options.dsn = "YOUR_DSN"
    options.environment = "production"
}
```

### Analytics

**TelemetryDeck** (privacy-focused):

```swift
import TelemetryClient

TelemetryManager.initialize(with: "YOUR_APP_ID")
TelemetryManager.send("host_started")
```

---

## Version Management

### Semantic Versioning

- **Major**: Breaking changes (e.g., CLI command format change)
- **Minor**: New features (e.g., SSH tunnel support)
- **Patch**: Bug fixes

### Build Number

Auto-increment on each build:

```bash
# In Xcode build phase
buildNumber=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$INFOPLIST_FILE")
buildNumber=$((buildNumber + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $buildNumber" "$INFOPLIST_FILE"
```

---

## Rollback Strategy

### Keep Previous Version

```bash
# Before updating
cp -R /Applications/MCCPortForwarder.app \
   /Applications/MCCPortForwarder.app.backup
```

### Data Migration

```swift
// StorageService.swift
func migrateIfNeeded() {
    let version = UserDefaults.standard.integer(forKey: "dataVersion")
    
    switch version {
    case 0:
        migrateV0toV1()
        fallthrough
    case 1:
        migrateV1toV2()
        fallthrough
    default:
        UserDefaults.standard.set(2, forKey: "dataVersion")
    }
}
```

---

## Troubleshooting Deployment

### Common Issues

**1. "App is damaged and can't be opened"**
- **Cause**: Not notarized
- **Fix**: Notarize or `xattr -cr MCCPortForwarder.app`

**2. Process won't start**
- **Cause**: Hardened Runtime blocks Process API
- **Fix**: Add entitlement `com.apple.security.cs.allow-unsigned-executable-memory`

**3. Status bar icon doesn't appear**
- **Cause**: `LSUIElement` not set
- **Fix**: Check Info.plist has `<key>LSUIElement</key><true/>`

**4. Popover doesn't receive keyboard**
- **Cause**: App not activated
- **Fix**: Add `NSApplication.shared.activate(ignoringOtherApps: true)`

### Debug Build

```bash
# Enable verbose logging
defaults write com.mcc.portforwarder EnableDebugLogging -bool true

# View logs
log stream --predicate 'subsystem == "com.mcc.portforwarder"'
```

---

## Maintenance

### Regular Tasks

- **Weekly**: Check crash reports
- **Monthly**: Review analytics, plan features
- **Quarterly**: Update dependencies, test on latest macOS

### Dependency Updates

```bash
# Check for XcodeGen updates
brew upgrade xcodegen

# Update Xcode
# App Store → Updates
```

### macOS Compatibility

Test on:
- Current macOS (e.g., Sonoma 14)
- Previous macOS (e.g., Ventura 13)
- Minimum supported (per deployment target)

