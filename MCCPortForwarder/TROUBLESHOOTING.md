# Troubleshooting Guide

## Common Issues

### 1. App Won't Launch

**Symptom**: Double-click does nothing, no status bar icon appears.

**Diagnosis**:
```bash
# Check if app is damaged
xattr -l /Applications/MCCPortForwarder.app

# Check console for errors
log show --predicate 'processImagePath contains "MCCPortForwarder"' --last 5m
```

**Solutions**:

a) **Remove quarantine attribute**:
```bash
xattr -cr /Applications/MCCPortForwarder.app
```

b) **Check permissions**:
```bash
chmod -R 755 /Applications/MCCPortForwarder.app
```

c) **Reinstall**:
```bash
rm -rf /Applications/MCCPortForwarder.app
make install
```

---

### 2. Status Bar Icon Missing

**Symptom**: App runs but no icon in status bar.

**Check**:
```bash
# Verify LSUIElement is set
/usr/libexec/PlistBuddy -c "Print LSUIElement" \
  /Applications/MCCPortForwarder.app/Contents/Info.plist
# Should print: true
```

**Solution**:
```bash
# Kill any running instances
killall MCCPortForwarder

# Clear cached preferences
defaults delete com.mcc.portforwarder

# Restart
open /Applications/MCCPortForwarder.app
```

---

### 3. Port Forward Fails to Start

**Symptom**: Click Start, but host shows "Error" immediately.

**Diagnosis**:
```bash
# Test mcc command directly
/usr/local/bin/mcc tp-port-forward <hostname>

# Check if mcc exists
which mcc
# Should print: /usr/local/bin/mcc
```

**Solutions**:

a) **Binary not found**:
```swift
// Modify ProcessService.swift
process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mcc")
// Or add to PATH
```

b) **Permission denied**:
```bash
chmod +x /usr/local/bin/mcc
```

c) **Check environment**:
```swift
// Add to ProcessService.startHost()
process.environment = ProcessInfo.processInfo.environment
```

---

### 4. Processes Don't Stop

**Symptom**: Click Stop, but process keeps running.

**Check running processes**:
```bash
ps aux | grep "mcc tp-port-forward"
```

**Force kill**:
```bash
killall -9 mcc
```

**Debug**:
```swift
// ProcessService.swift - add logging
func stopHost(_ hostId: UUID) {
    print("Stopping host: \(hostId)")
    
    if info.process.isRunning {
        print("Sending SIGTERM to PID: \(info.process.processIdentifier)")
        info.process.terminate()
    }
}
```

---

### 5. Data Not Persisting

**Symptom**: Services disappear after restart.

**Check storage**:
```bash
# View stored data
defaults read com.mcc.portforwarder services

# Check file permissions
ls -la ~/Library/Preferences/com.mcc.portforwarder.plist
```

**Reset storage**:
```bash
defaults delete com.mcc.portforwarder
```

**Debug save/load**:
```swift
// StorageService.swift
func saveServices(_ services: [Service]) {
    do {
        let data = try JSONEncoder().encode(services)
        defaults.set(data, forKey: storageKey)
        defaults.synchronize()  // Force write
        print("Saved \(services.count) services")
    } catch {
        print("SAVE ERROR: \(error)")
    }
}
```

---

### 6. UI Not Updating

**Symptom**: Start process, but UI still shows "Stopped".

**Check**:
- Is Timer running?
- Is processService returning correct state?
- Is hostStates being updated?

**Debug**:
```swift
// AppViewModel.swift
private func updateHostStates() {
    for service in services {
        for host in service.hosts {
            let state = processService.getHostState(host.id)
            print("Host \(host.name): \(state)")
            hostStates[host.id] = state
        }
    }
}
```

**Common cause**: @MainActor not on ViewModel
```swift
@MainActor  // ← Make sure this is present
final class AppViewModel: ObservableObject {
```

---

### 7. Memory Leak

**Symptom**: App uses increasing memory over time.

**Profile with Instruments**:
```bash
# Build for profiling
xcodebuild -project MCCPortForwarder.xcodeproj \
  -scheme MCCPortForwarder \
  -configuration Debug \
  build

# Open Instruments
open -a Instruments
# Choose "Leaks" template
# Select MCCPortForwarder.app
```

**Common causes**:

a) **Missing [weak self]**:
```swift
// ❌ Retain cycle
process.terminationHandler = { process in
    self.handleTermination(...)
}

// ✅ Fixed
process.terminationHandler = { [weak self] process in
    self?.handleTermination(...)
}
```

b) **Timer not invalidated**:
```swift
deinit {
    stateTimer?.invalidate()  // ← Essential
    stateTimer = nil
}
```

c) **File handles not closed**:
```swift
handle.readabilityHandler = { fileHandle in
    let data = fileHandle.availableData
    if data.isEmpty {
        fileHandle.readabilityHandler = nil  // ← Clean up
        return
    }
}
```

---

### 8. Popover Keyboard Input Broken

**Symptom**: Can click buttons, but can't type in TextFields.

**Solution**:
```swift
// AppDelegate.swift - in togglePopover()
if popover.isShown {
    popover.performClose(nil)
} else {
    popover.show(...)
    NSApplication.shared.activate(ignoringOtherApps: true)  // ← Add this
}
```

---

### 9. Build Errors in Xcode

**Error**: "No such module 'SwiftUI'"

**Solution**: Check deployment target
```yaml
# project.yml
MACOSX_DEPLOYMENT_TARGET: "13.0"
```

**Error**: "Command XcodeGen not found"

**Solution**:
```bash
brew install xcodegen
```

**Error**: "Signing for requires a development team"

**Solution**:
```yaml
# project.yml
CODE_SIGN_IDENTITY: "-"
CODE_SIGN_STYLE: Automatic
```

---

### 10. Crash on Launch

**Get crash log**:
```bash
# View recent crashes
open ~/Library/Logs/DiagnosticReports/

# Or via Console.app
open -a Console
# Filter: process:MCCPortForwarder
```

**Common causes**:

a) **Force unwrap nil**:
```swift
// ❌ Crash if button is nil
statusItem!.button!.image = ...

// ✅ Safe
if let button = statusItem?.button {
    button.image = ...
}
```

b) **Missing resource**:
```swift
// Check if image exists
if let image = NSImage(systemSymbolName: "...", accessibilityDescription: nil) {
    button.image = image
}
```

---

## Debug Techniques

### 1. Console Logging

```swift
// ProcessService.swift - track all operations
func startHost(...) {
    print("=== START HOST ===")
    print("Host ID: \(hostId)")
    print("Hostname: \(hostname)")
    print("Binary: \(process.executableURL?.path ?? "nil")")
    print("Arguments: \(process.arguments ?? [])")
    
    do {
        try process.run()
        print("✓ Process started: PID \(process.processIdentifier)")
    } catch {
        print("✗ Process failed: \(error)")
    }
}
```

### 2. Breakpoints

```swift
// Set breakpoint here to inspect state
func toggleHost(_ hostId: UUID, hostname: String) {
    let state = hostStates[hostId] ?? .stopped  // ← Breakpoint
    // Inspect: po hostStates, po state
}
```

### 3. Environment Variables

```bash
# Enable debug logging
export MCC_DEBUG=1

# Run app from terminal
open /Applications/MCCPortForwarder.app
```

```swift
// Check in code
if ProcessInfo.processInfo.environment["MCC_DEBUG"] != nil {
    // Verbose logging
}
```

### 4. Network Debugging

```bash
# Check if ports are actually forwarded
lsof -i -P | grep LISTEN

# Test connection
nc -zv localhost <port>
```

---

## Performance Issues

### High CPU Usage

**Diagnosis**:
```bash
# Monitor CPU
top -pid $(pgrep MCCPortForwarder)

# Sample for 10 seconds
sample MCCPortForwarder 10
```

**Common causes**:
- Timer interval too frequent (< 1 second)
- Infinite loop in state updates
- Too many concurrent processes

**Solutions**:
```swift
// Increase polling interval
Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true)

// Limit concurrent connections
let maxConcurrentHosts = 50
guard processes.count < maxConcurrentHosts else { return }
```

### High Memory Usage

**Diagnosis**:
```bash
# Check memory
ps aux | grep MCCPortForwarder

# Detailed analysis
leaks MCCPortForwarder
```

**Solutions**:
- Reduce state polling frequency
- Clear completed process info
- Limit log buffer size

---

## Known Limitations

### 1. macOS Version Compatibility

- **Minimum**: macOS 13.0 (Ventura)
- **Reason**: SwiftUI features, modern Process API

### 2. Binary Path

- **Hardcoded**: `/usr/local/bin/mcc`
- **Workaround**: Symlink or modify code

### 3. No Process Output Viewing

- **Current**: Output only in console
- **Future**: Add log viewer in UI

### 4. No Connection Health Checks

- **Current**: Only start/stop state
- **Future**: Ping endpoint, show latency

### 5. No Automatic Reconnect

- **Current**: Manual restart on failure
- **Future**: Auto-retry with backoff

---

## Getting Help

### 1. Check Logs

```bash
# System logs
log show --predicate 'processImagePath contains "MCCPortForwarder"' --last 1h

# User defaults
defaults read com.mcc.portforwarder
```

### 2. Clean Reinstall

```bash
# Stop app
killall MCCPortForwarder

# Remove app
rm -rf /Applications/MCCPortForwarder.app

# Clear preferences
defaults delete com.mcc.portforwarder

# Reinstall
make install
```

### 3. Report Issue

Include:
- macOS version: `sw_vers`
- App version: Check "About" or Info.plist
- Console logs
- Steps to reproduce

---

## Advanced Debugging

### LLDB Commands

```bash
# Attach to running process
lldb -p $(pgrep MCCPortForwarder)

# Set breakpoint
(lldb) br set -n startHost

# Continue
(lldb) continue

# Print variable
(lldb) po processes

# Detach
(lldb) detach
```

### DTrace

```bash
# Trace file operations
sudo dtruss -p $(pgrep MCCPortForwarder)

# Trace system calls
sudo dtruss -t read,write -p $(pgrep MCCPortForwarder)
```

### Network Tracing

```bash
# Capture traffic
sudo tcpdump -i any port <your_port> -w capture.pcap

# Analyze in Wireshark
open capture.pcap
```

