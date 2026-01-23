# Quick Start Guide

## 5-Minute Setup

### Prerequisites

- macOS 13.0+ (Ventura or later)
- Xcode 15.0+
- `mcc` CLI installed at `/usr/local/bin/mcc`

### Installation

```bash
cd /Users/max/mcc/MCCPortForwarder
make setup
make run
```

App appears in status bar (arrow icon) → Click to open.

---

## First Use

### 1. Add Your First Service

Click **`+`** button → Enter service name (e.g., "Production") → Click **Add**.

### 2. Add Hosts

1. Click **chevron** to expand service
2. Click **Add Host**
3. Enter:
   - **Host Name**: Display name (e.g., "DB Server")
   - **Hostname**: Actual hostname for `mcc` command
4. Click **Add**

### 3. Start Port Forwarding

**Option A**: Single host
- Click **play icon** (▶) next to host

**Option B**: Entire service
- Click **Start** button next to service name

**Option C**: Everything
- Click **Start All** at bottom

---

## Example Configuration

### Development Environment

**Service**: Development  
**Hosts**:
- Name: `Dev DB`, Hostname: `dev-db.example.com`
- Name: `Dev API`, Hostname: `dev-api.example.com`
- Name: `Dev Redis`, Hostname: `dev-redis.example.com`

### Production Environment

**Service**: Production  
**Hosts**:
- Name: `Prod DB`, Hostname: `prod-db.example.com`
- Name: `Prod API`, Hostname: `prod-api.example.com`

### Quick Connect

**Service**: Quick  
**Hosts**:
- Name: `Localhost`, Hostname: `localhost:8080`

---

## Daily Usage

### Starting Your Day

1. Click status bar icon
2. Click **Start All**
3. Verify green dots appear
4. Close popover (click outside)

### Switching Contexts

1. Stop current service: Click **Stop** next to service
2. Start different service: Click **Start** next to other service

### Troubleshooting Connection

1. Click **stop icon** (■) next to failing host
2. Wait for gray dot
3. Click **play icon** (▶) to restart
4. Check status: Green = success, Red = error

---

## Understanding Status Colors

| Color | Meaning | Action |
|-------|---------|--------|
| 🟢 Green | Running | Connection active |
| 🔴 Red | Error | Check console logs, restart |
| ⚫ Gray | Stopped | Ready to start |

---

## CLI Command Reference

The app runs this command for each host:

```bash
/usr/local/bin/mcc tp-port-forward <hostname>
```

### Testing Manually

```bash
# Test if mcc works
mcc tp-port-forward dev-db.example.com

# Check if port is forwarded
lsof -i -P | grep LISTEN

# Stop all mcc processes
killall mcc
```

---

## Keyboard Workflow

1. Click status bar icon (or assign hotkey)
2. Type in search field (future feature)
3. Arrow keys to navigate
4. Space to toggle host
5. Esc to close

---

## Tips & Tricks

### Organize Services

Use descriptive names:
- ✅ "Production East"
- ✅ "Staging v2"
- ✅ "Local Dev"
- ❌ "Service 1"
- ❌ "Test"

### Naming Hosts

Include purpose in name:
- ✅ "PostgreSQL Main"
- ✅ "Redis Cache"
- ✅ "API Gateway"
- ❌ "Server 1"
- ❌ "db"

### Bulk Operations

**Start all dev servers**:
1. Add all to "Development" service
2. Click service **Start** button

**Emergency stop**:
1. Click **Stop All** at bottom
2. All connections terminate in 2 seconds

### Monitoring

**Active connections**: Bottom right shows count

**System resources**:
```bash
# Check memory/CPU
ps aux | grep MCCPortForwarder

# Check active mcc processes
ps aux | grep "mcc tp-port-forward"
```

---

## Common Workflows

### Workflow 1: Daily Development

```
Morning:
1. Open laptop
2. Click status bar → Start All
3. Work all day

Evening:
4. Click status bar → Stop All
5. Close laptop
```

### Workflow 2: Context Switching

```
1. Working on Feature A (Service: Feature-A running)
2. Need to debug Production issue
3. Stop Service: Feature-A
4. Start Service: Production
5. Debug and fix
6. Stop Service: Production
7. Start Service: Feature-A
8. Continue work
```

### Workflow 3: On-Call Debugging

```
1. Get alert
2. Click status bar
3. Start Service: Production
4. Verify connections (green dots)
5. Use local tools to connect
6. Debug issue
7. Fix deployed
8. Stop Service: Production
```

---

## Data Backup

Your configuration is stored in:
```
~/Library/Preferences/com.mcc.portforwarder.plist
```

### Manual Backup

```bash
# Export configuration
defaults export com.mcc.portforwarder ~/mcc-backup.plist

# Import configuration
defaults import com.mcc.portforwarder ~/mcc-backup.plist
```

### Sync Across Machines

```bash
# On Machine A
defaults export com.mcc.portforwarder ~/Dropbox/mcc-config.plist

# On Machine B
defaults import com.mcc.portforwarder ~/Dropbox/mcc-config.plist
killall MCCPortForwarder  # Restart app
```

---

## Uninstall

### Remove App

```bash
rm -rf /Applications/MCCPortForwarder.app
```

### Remove Data

```bash
defaults delete com.mcc.portforwarder
```

### Complete Cleanup

```bash
# Stop app
killall MCCPortForwarder

# Remove app
rm -rf /Applications/MCCPortForwarder.app

# Remove data
defaults delete com.mcc.portforwarder

# Remove preferences
rm ~/Library/Preferences/com.mcc.portforwarder.plist

# Kill any orphaned processes
killall mcc
```

---

## Next Steps

### Customize

- Edit `ProcessService.swift` to change command
- Edit `ContentView.swift` to adjust UI
- Edit `Info.plist` to change app name

### Extend

- Add SSH tunnel support
- Add connection health checks
- Add auto-reconnect
- Add global keyboard shortcut

### Distribute

See `DEPLOYMENT.md` for:
- Building release version
- Code signing
- Notarization
- DMG creation

---

## Getting Help

### Debug Mode

```bash
# Enable debug logging
defaults write com.mcc.portforwarder EnableDebug -bool true

# View logs
log stream --predicate 'subsystem == "com.mcc.portforwarder"'
```

### Common Issues

**App won't start**: See `TROUBLESHOOTING.md` → Section 1

**Process fails**: See `TROUBLESHOOTING.md` → Section 3

**Data not saved**: See `TROUBLESHOOTING.md` → Section 5

### Resources

- **Architecture**: `ARCHITECTURE.md` - Deep technical dive
- **Deployment**: `DEPLOYMENT.md` - Release and distribution
- **Troubleshooting**: `TROUBLESHOOTING.md` - Fix common issues
- **Code**: `MCCPortForwarder/` - Source files with comments

---

## Example: Complete Setup

```bash
# 1. Setup project
cd /Users/max/mcc/MCCPortForwarder
make setup

# 2. Build and run
make run

# App launches, appears in status bar

# 3. Configure (in UI)
# Add Service: "My Project"
# Add Host: Name="Database", Hostname="db.myproject.local"
# Add Host: Name="API", Hostname="api.myproject.local"
# Click "Start" next to "My Project"

# 4. Verify
lsof -i -P | grep mcc
# Should show 2 processes

# 5. Test connection
nc -zv localhost <port>
# Should connect

# 6. Daily use
# Click status bar icon → Start All
# Work...
# Click status bar icon → Stop All
```

---

## Performance Expectations

- **Startup time**: < 1 second
- **Process start**: < 500ms per host
- **Process stop**: < 2 seconds (graceful)
- **UI refresh**: 1 second (polling interval)
- **Memory usage**: ~5-10 MB + 1 MB per connection
- **CPU usage**: < 0.1% idle, < 1% active

---

## Production Checklist

Before using in production:

- [ ] Test with actual hostnames
- [ ] Verify `mcc` command works manually
- [ ] Configure error logging
- [ ] Setup automatic backups of config
- [ ] Document team workflows
- [ ] Add to onboarding guide
- [ ] Create team wiki page

---

## Success!

You now have a working port-forward manager. Click the status bar icon and start managing your connections!

**Questions?** Check `README.md` or `TROUBLESHOOTING.md`.

