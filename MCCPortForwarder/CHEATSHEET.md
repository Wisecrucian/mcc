# MCC Port Forwarder - Cheat Sheet

Quick reference for common tasks.

---

## Setup

```bash
# Initial setup
cd /Users/max/mcc/MCCPortForwarder
make setup

# Build and run
make run

# Release build
make build

# Install to /Applications
make install
```

---

## Project Structure

```
MCCPortForwarder/
├── App/              # Entry point + status bar
├── Models/           # Data structures
├── Services/         # Business logic
├── ViewModels/       # State management
└── Views/            # UI components
```

---

## Key Files

| File | Purpose |
|------|---------|
| `AppDelegate.swift` | Status bar + popover |
| `AppViewModel.swift` | Main state logic |
| `ProcessService.swift` | CLI management |
| `ContentView.swift` | Main UI |
| `project.yml` | XcodeGen config |

---

## Build Commands

```bash
make setup      # Generate .xcodeproj
make build      # Release build
make run        # Debug build + launch
make clean      # Clean artifacts
make install    # Install to /Applications
```

---

## User Workflow

```
1. Click status bar icon
2. Click + to add service
3. Expand service (chevron)
4. Add hosts
5. Click "Start" next to service
6. Verify green dots
7. Click "Stop All" when done
```

---

## Data Location

```bash
# Configuration storage
~/Library/Preferences/com.mcc.portforwarder.plist

# View config
defaults read com.mcc.portforwarder

# Export config
defaults export com.mcc.portforwarder ~/backup.plist

# Import config
defaults import com.mcc.portforwarder ~/backup.plist

# Reset config
defaults delete com.mcc.portforwarder
```

---

## Process Management

```bash
# Check running processes
ps aux | grep "mcc tp-port-forward"

# Kill all mcc processes
killall mcc

# Check app process
ps aux | grep MCCPortForwarder

# Kill app
killall MCCPortForwarder
```

---

## Status Colors

| Color | State | Meaning |
|-------|-------|---------|
| 🟢 Green | Running | Connection active |
| 🔴 Red | Error | Connection failed |
| ⚫ Gray | Stopped | Ready to start |

---

## Debugging

```bash
# View console logs
log show --predicate 'processImagePath contains "MCCPortForwarder"' --last 5m

# Stream logs
log stream --predicate 'subsystem == "com.mcc.portforwarder"'

# Check ports
lsof -i -P | grep mcc

# Test connection
nc -zv localhost <port>
```

---

## Common Issues

### App won't start
```bash
xattr -cr /Applications/MCCPortForwarder.app
```

### Status bar icon missing
```bash
killall MCCPortForwarder
open /Applications/MCCPortForwarder.app
```

### Process fails to start
```bash
# Check binary exists
ls -la /usr/local/bin/mcc

# Test manually
/usr/local/bin/mcc tp-port-forward hostname
```

### Data not saved
```bash
# Verify storage
defaults read com.mcc.portforwarder

# Reset if corrupted
defaults delete com.mcc.portforwarder
```

---

## Code Patterns

### Add ViewModel Method
```swift
// AppViewModel.swift
func newFeature() {
    // Call service
    processService.doSomething { result in
        Task { @MainActor in
            // Update @Published state
            self.someState = result
        }
    }
}
```

### Add View Component
```swift
// NewView.swift
struct NewView: View {
    var body: some View {
        // SwiftUI code
    }
}
```

### Add Service Method
```swift
// ProcessService.swift
func newOperation() {
    queue.async(flags: .barrier) {
        // Thread-safe operation
    }
}
```

---

## Architecture Rules

✅ **DO**
- Put state in ViewModel
- Use `[weak self]` in closures
- Call services from ViewModel
- Update UI on `@MainActor`
- Use barriers for writes

❌ **DON'T**
- Put logic in Views
- Access services from Views
- Force unwrap optionals
- Block main thread
- Mix AppKit in SwiftUI views

---

## Testing

```bash
# Unit tests (TODO)
⌘ + U in Xcode

# Manual testing checklist
- [ ] Add service
- [ ] Add host
- [ ] Start host
- [ ] Stop host
- [ ] Delete host
- [ ] Delete service
- [ ] Start All
- [ ] Stop All
- [ ] Quit app (processes stop?)
- [ ] Relaunch (data persists?)
```

---

## Environment Check

```bash
./check-env.sh
```

Should show:
- ✓ macOS 13.0+
- ✓ Xcode
- ✓ XcodeGen
- ✓ make

---

## Quick Reference

| Task | Command |
|------|---------|
| Setup project | `make setup` |
| Build & run | `make run` |
| View logs | `log show ... \| grep MCC` |
| Check processes | `ps aux \| grep mcc` |
| Reset data | `defaults delete com.mcc.portforwarder` |
| Kill app | `killall MCCPortForwarder` |
| View config | `defaults read com.mcc.portforwarder` |

---

## File Shortcuts

```bash
# Open in Xcode
open MCCPortForwarder.xcodeproj

# Open in Finder
open .

# View structure
tree -L 3

# Count lines
find . -name "*.swift" -exec wc -l {} +
```

---

## Documentation

| File | Topic |
|------|-------|
| `README.md` | Overview |
| `QUICKSTART.md` | Setup guide |
| `ARCHITECTURE.md` | Technical details |
| `DEPLOYMENT.md` | Release process |
| `TROUBLESHOOTING.md` | Fix issues |
| `EXAMPLES.md` | Usage scenarios |
| `CHEATSHEET.md` | This file |

---

## Hotkeys (in Xcode)

| Key | Action |
|-----|--------|
| ⌘ + B | Build |
| ⌘ + R | Run |
| ⌘ + . | Stop |
| ⌘ + U | Test |
| ⌘ + K | Clean |
| ⌘ + ⇧ + K | Clean build folder |

---

## Git Workflow

```bash
# Initialize repo
git init
git add .
git commit -m "Initial commit"

# Ignore generated files (.gitignore already configured)
# - *.xcodeproj (generated by XcodeGen)
# - DerivedData/
# - .DS_Store
```

---

## Quick Edits

### Change binary path
```swift
// ProcessService.swift:54
process.executableURL = URL(fileURLWithPath: "/your/path/mcc")
```

### Change window size
```swift
// ContentView.swift:30
.frame(width: 500, height: 600)  // was 400×500
```

### Change polling interval
```swift
// AppViewModel.swift:126
Timer.scheduledTimer(withTimeInterval: 2.0, ...)  // was 1.0
```

---

## Performance Tuning

```bash
# Profile CPU
instruments -t "Time Profiler" MCCPortForwarder.app

# Profile Memory
instruments -t "Allocations" MCCPortForwarder.app

# Check leaks
leaks MCCPortForwarder

# Monitor in real-time
top -pid $(pgrep MCCPortForwarder)
```

---

## Deployment Checklist

- [ ] Update version in `project.yml`
- [ ] Update `CHANGELOG.md`
- [ ] `make build`
- [ ] Test release build
- [ ] Code sign
- [ ] Notarize
- [ ] Create DMG
- [ ] Upload to release page

---

## Keyboard Maestro Trigger

```applescript
-- Toggle popover
tell application "System Events"
    tell process "MCCPortForwarder"
        click menu bar item 1 of menu bar 2
    end tell
end tell
```

---

## Backup & Restore

```bash
# Backup
defaults export com.mcc.portforwarder ~/mcc-backup-$(date +%Y%m%d).plist

# Restore
defaults import com.mcc.portforwarder ~/mcc-backup-YYYYMMDD.plist

# Sync to Dropbox
cp ~/Library/Preferences/com.mcc.portforwarder.plist ~/Dropbox/
```

---

## Resources

- [Apple Docs](https://developer.apple.com/documentation/)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)
- [Process API](https://developer.apple.com/documentation/foundation/process)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

---

**Pro Tip**: Bookmark this file for quick reference!

---

*Last Updated: 2026-01-23*

