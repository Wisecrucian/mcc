# Architecture Deep Dive

## MVVM Implementation

### View Layer
**Responsibility**: Display data, capture user input  
**Rules**: 
- No business logic
- No direct service access
- Only talks to ViewModel
- Pure SwiftUI, no AppKit (except AppDelegate)

```swift
// ✅ Good
Button("Start") {
    viewModel.startService(service)
}

// ❌ Bad - business logic in View
Button("Start") {
    processService.startHost(...)
}
```

### ViewModel Layer
**Responsibility**: State management, coordinate services  
**Rules**:
- @MainActor for UI updates
- Observable state (@Published)
- Orchestrates service calls
- No direct UI references

```swift
// ✅ Good - single source of truth
@Published var hostStates: [UUID: ProcessState] = [:]

// ❌ Bad - computed in View
var hostState: ProcessState {
    processService.getHostState(id)
}
```

### Service Layer
**Responsibility**: Pure business logic, no UI  
**Rules**:
- Thread-safe operations
- Completion handlers for async work
- No @Published properties
- No SwiftUI imports

---

## Process Management

### Thread Safety

**ProcessService** uses concurrent queue with barriers:

```swift
private let queue = DispatchQueue(label: "...", attributes: .concurrent)

// Read operations - concurrent
func getHostState() {
    queue.sync { /* read */ }
}

// Write operations - barrier
func startHost() {
    queue.async(flags: .barrier) { /* write */ }
}
```

**Why**: Multiple reads OK, writes must be exclusive.

### Process Lifecycle

```
startHost()
    │
    ├─ Create Process
    ├─ Setup Pipes (stdout/stderr)
    ├─ Set termination handler
    ├─ Try process.run()
    │
    ├─ Success:
    │   ├─ Store in processes dict
    │   ├─ Start reading pipes
    │   └─ Callback .success
    │
    └─ Failure:
        └─ Callback .failure(error)

Process terminates (user/crash/exit)
    │
    ├─ terminationHandler called
    ├─ Update state based on exit code
    └─ Cleanup after 0.5s delay

stopHost()
    │
    ├─ Send SIGTERM (graceful)
    ├─ Wait 2 seconds
    └─ Send SIGKILL if still running
```

### Pipe Reading

**Non-blocking async reading**:

```swift
let handle = pipe.fileHandleForReading

handle.readabilityHandler = { fileHandle in
    let data = fileHandle.availableData
    if data.isEmpty {
        // EOF - cleanup
        fileHandle.readabilityHandler = nil
        return
    }
    // Process output
}
```

**Why not**: `availableData` sync call → would block  
**Solution**: readabilityHandler fires when data available

### Error Detection

1. **Launch failure**: Process.run() throws
2. **Process crash**: terminationStatus != 0
3. **stderr output**: Treated as error indicator
4. **Forced termination**: SIGKILL → .error state

---

## State Management

### State Flow

```
User Action (View)
    ↓
ViewModel method
    ↓
Service call (async)
    ↓
Completion handler
    ↓
Update @Published state (MainActor)
    ↓
SwiftUI redraws automatically
```

### State Polling

**Problem**: Process can terminate externally  
**Solution**: 1-second timer polling

```swift
Timer.scheduledTimer(withTimeInterval: 1.0) {
    updateHostStates()  // Check all processes
}
```

**Alternative considered**: Notification-based → too complex  
**Trade-off**: 1-second lag vs. complexity

### State Aggregation

Service state = aggregation of host states:

```swift
func getServiceState(_ service: Service) -> ProcessState {
    let hostStates = service.hosts.map { getHostState($0.id) }
    
    if hostStates.allSatisfy({ $0 == .running }) {
        return .running  // All running
    } else if hostStates.contains(.running) {
        return .running  // Partial running (still "active")
    } else if hostStates.contains(.error) {
        return .error    // Has errors
    } else {
        return .stopped  // All stopped
    }
}
```

---

## Persistence

### Why UserDefaults

- Simple key-value storage
- Automatic persistence
- No schema migration needed
- Fast for small datasets

### Codable Models

```swift
struct Service: Codable {
    let id: UUID
    var name: String
    var hosts: [Host]
}
```

**Encoding**:
```swift
let data = try JSONEncoder().encode(services)
defaults.set(data, forKey: key)
```

**Decoding**:
```swift
let data = defaults.data(forKey: key)
let services = try JSONDecoder().decode([Service].self, from: data)
```

### When to Save

- After every mutation (add/delete/update)
- Never on state changes (process start/stop)

**Why**: State is runtime-only, config is persistent

---

## Status Bar Integration

### AppKit Bridge

SwiftUI can't create status bar items → use AppKit:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    func applicationDidFinishLaunching() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(...)
        
        // Embed SwiftUI view
        popover = NSPopover()
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
        )
        
        // Hide dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
```

### Popover Behavior

**transient**: Closes on click outside  
**Why not semitransient**: Want standard macOS behavior  
**Why not applicationDefined**: Too custom

### Activation

```swift
NSApplication.shared.activate(ignoringOtherApps: true)
```

**Needed**: Popover receives keyboard events  
**Without**: Clicks work, typing doesn't

---

## Memory Management

### Weak Self

Always use `[weak self]` in async contexts:

```swift
process.terminationHandler = { [weak self] process in
    self?.handleTermination(...)
}
```

**Why**: Process holds handler → handler holds self → retain cycle

### Cleanup

```swift
deinit {
    stopAllProcesses()
    stateTimer?.invalidate()
}
```

**Guaranteed**: App termination → ViewModel deinit → all processes stopped

---

## Error Handling

### Strategy

1. **Service Layer**: Return Result<T, Error>
2. **ViewModel**: Map to ProcessState
3. **View**: Display state visually

### Example Flow

```swift
// Service
completion(.failure(ProcessError.binaryNotFound))
    ↓
// ViewModel
case .failure(let error):
    hostStates[id] = .error
    print(error)  // Debug logging
    ↓
// View
Circle().fill(.red)  // Visual indicator
```

### No Alert Dialogs

**Why**: Status bar app, minimal UI  
**Solution**: Visual state + console logging

---

## Extension Patterns

### Adding Features

**New host property** (e.g., port number):

1. Update `Host` model:
```swift
struct Host {
    var port: Int
}
```

2. Update `StorageService`: Auto-handled by Codable

3. Update UI:
```swift
TextField("Port", value: $newHostPort, format: .number)
```

4. Update `ProcessService`:
```swift
process.arguments = ["tp-port-forward", hostname, "--port", "\(port)"]
```

**New process type** (e.g., ssh tunnel):

1. Add enum:
```swift
enum ConnectionType {
    case portForward
    case sshTunnel
}
```

2. Update `ProcessService.startHost()`:
```swift
switch type {
case .portForward:
    args = ["tp-port-forward", ...]
case .sshTunnel:
    args = ["ssh", "-L", ...]
}
```

3. Update UI with picker

---

## Testing Strategy

### Unit Tests

**ProcessService**:
- Mock Process → test state transitions
- Test thread safety with expectation timeouts
- Test cleanup on deinit

**AppViewModel**:
- Mock ProcessService
- Test state aggregation
- Test persistence calls

### UI Tests

- Launch app
- Find status bar (XCUIApplication)
- Click status item
- Verify popover appears
- Test add/delete flows

### Manual Testing

- Memory leaks: Instruments → Leaks
- Process cleanup: Activity Monitor
- State accuracy: Multiple rapid start/stops

---

## Performance Considerations

### Optimization Points

1. **State polling**: 1s interval → balance accuracy vs. CPU
2. **Pipe reading**: Async handlers → no blocking
3. **Queue barriers**: Minimize lock contention
4. **SwiftUI updates**: @Published → auto-batching

### Bottlenecks

- N hosts → N processes → N pipes → 2N file handles
- Limit: System file descriptor limit (~10k)
- Practical limit: ~100 concurrent connections

### Profiling

```bash
# CPU profiling
instruments -t "Time Profiler" MCCPortForwarder.app

# Memory profiling
instruments -t "Allocations" MCCPortForwarder.app
```

---

## Production Hardening

### Must-Haves

1. **Logging**: os_log for system integration
2. **Crash Reporting**: Sentry/Crashlytics
3. **Analytics**: Track feature usage
4. **Auto-updater**: Sparkle framework
5. **Code Signing**: Distribution outside App Store

### Nice-to-Haves

1. **Custom icons**: SF Symbols for status bar
2. **Keyboard shortcuts**: Global hotkeys
3. **Menu extras**: Recent connections
4. **Export/Import**: Share configs

### Security

- Sandbox: Not feasible (needs Process execution)
- Hardened Runtime: Enable for notarization
- Entitlements: `com.apple.security.app-sandbox = NO`

---

## Common Pitfalls

### ❌ UI in Service Layer

```swift
// BAD
class ProcessService {
    @Published var state: ProcessState  // NO!
}
```

**Fix**: Use completion handlers

### ❌ Blocking Main Thread

```swift
// BAD
let output = pipe.fileHandleForReading.availableData  // Blocks!
```

**Fix**: Use readabilityHandler

### ❌ Force Unwrapping

```swift
// BAD
statusItem!.button!.image = ...  // Can crash
```

**Fix**: Guard or if-let

### ❌ State in UserDefaults

```swift
// BAD
defaults.set(processIsRunning, forKey: "state")
```

**Fix**: State is runtime-only, never persist

---

## Questions & Decisions

### Why not CoreData?

- Overhead for simple models
- No relationships needed
- Migration complexity

### Why not TCA (The Composable Architecture)?

- Learning curve
- Overkill for this scale
- Want simple, readable code

### Why not Combine for process events?

- Process API is callback-based
- No benefit over completion handlers
- Adds dependency

### Why UserDefaults over JSON file?

- Atomic writes built-in
- System handles caching
- Standard for preferences

### Why polling vs. notifications?

- Process termination → already has handler
- External checks → need polling anyway
- Simpler implementation

