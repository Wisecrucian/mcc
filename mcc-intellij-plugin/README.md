# MCC Port Forwarder - IntelliJ IDEA Plugin

IntelliJ IDEA plugin for managing port forwarding connections. Full port of the MCCPortForwarder macOS app.

## ✨ Features

### 🌳 Hierarchical Service Management
- Manage services and hosts in a tree view
- Multiple port mappings per host
- Multi-datacenter support with location templates  
- Real-time status updates

### 🎮 Interactive Controls
- **Right-click context menu** for all operations
- **Double-click** ports to toggle start/stop
- **Toolbar buttons** for quick actions
- **Active connections counter**

### 🚀 Port Forwarding Operations
- **Start/Stop** individual ports, hosts, or entire services
- **Kill Process** on occupied ports (lsof + kill -9)
- **View Logs** for each port connection
- **Real-time status** tracking with emoji indicators
- **Auto-retry** on connection failure

### 📊 Status Indicators
- 🔵 **Connecting** - Process started
- 🟡 **Authenticating** - Authentication in progress
- 🟢 **Ready** - Connection established and proxying
- 🔴 **Error** - Connection failed
- 🟠 **Timeout** - Connection timeout
- 🟠 **Port Busy** - Port already in use
- 🔄 **Restarting** - Auto-retry in progress
- 🟣 **Disconnected** - Connection dropped
- ⏹️ **Stopped** - Not running

### 💾 Configuration Management
- **Export** configuration to JSON
- **Import** configuration from JSON
- **Add/Edit/Delete** services
- **Settings dialog** for commands and retry options
- Auto-save and persistent state

## 🏗️ Building

```bash
cd mcc-intellij-plugin
./gradlew clean buildPlugin
```

The plugin will be built to `build/distributions/mcc-intellij-plugin-1.0.0.zip`

## 📦 Installing (without marketplace)

### 1. Uninstall Old Version (if exists)
```
Settings (⌘,) → Plugins → Installed
  → Find "MCC Port Forwarder" → ⚙️ → Uninstall → OK
```
**Restart IDE!**

### 2. Install New Version
```
Settings → Plugins → ⚙️ → Install Plugin from Disk...
  → Select: mcc-intellij-plugin/build/distributions/mcc-intellij-plugin-1.0.0.zip
  → OK
```
**Restart IDE again!**

### 3. Open Tool Window
```
View → Tool Windows → MCCPortForwarder
```
Or find **"MCCPortForwarder"** tab on the right side panel.

## 🎯 Quick Start

1. **Open Tool Window**: `View → Tool Windows → MCCPortForwarder`
2. **Add Test Data**: Click "🧪 Add Test Data" button
3. **Start Port**: Double-click on any port or right-click → "Start"
4. **View Status**: Watch emoji change from 🔵 → 🟡 → 🟢
5. **Stop Port**: Double-click again or right-click → "Stop"

## 📖 Usage Guide

### Adding Services

**Quick Way (Test Data)**
- Click **"🧪 Add Test Data"** → Get sample service with 2 datacenters

**Custom Way**
- Click **"➕ Add Service"** → Enter name → OK

### Starting/Stopping Ports

- **Double-click** on port to toggle
- **Right-click** → "Start" / "Stop"
- **Toolbar**: "▶️ Start All" / "⏹️ Stop All"

### Managing Services

- **Edit**: Right-click service → "Edit" → Change name
- **Delete**: Right-click service → "Delete" → Confirm
- All ports auto-stopped before deletion

### Settings

Click **"⚙️ Settings"** to configure:
- **Command**: `/usr/local/bin/mcc tp-port-forward`
- **Login/Logout Commands**
- **Retry**: Enabled, attempts, delay
- **Datacenters**: Comma-separated list

### Export/Import

- **Export**: "📤 Export" → Select folder → `mcc-config-export.json` created
- **Import**: "📥 Import" → Select JSON file → Services loaded

### Killing Processes

If port is busy:
- Right-click port → "Kill Process on Port" → Confirm
- Uses `lsof` + `kill -9`

### Viewing Logs

- Right-click port → "View Logs"
- Shows last 50 log lines

## 🗂️ Configuration Format

```json
{
  "version": "1.0",
  "services": [{
    "name": "My Service",
    "hosts": [{
      "name": "My Host",
      "hostnameTemplate": "host.{location}.example.com",
      "remotePort": 8080,
      "locations": [
        {"datacenter": "dc1", "localPort": 9001},
        {"datacenter": "dc2", "localPort": 9002}
      ]
    }]
  }],
  "settings": {
    "command": "/usr/local/bin/mcc tp-port-forward",
    "loginCommand": "/usr/local/bin/mcc login",
    "logoutCommand": "/usr/local/bin/mcc logout",
    "retryEnabled": true,
    "retryAttempts": 3,
    "retryDelay": 5,
    "datacenters": ["dc1", "dc2", "dc3"]
  }
}
```

## 🐛 Troubleshooting

### Plugin won't load
1. Check IntelliJ IDEA version: **2024.1+**
2. Check JDK version: **17**
3. Clear caches: `rm -rf ~/Library/Caches/JetBrains/IntelliJIdea*`
4. Reinstall plugin

### Port won't start
1. Check command in Settings
2. Test command in terminal
3. View logs (right-click → View Logs)

### Port busy error
- Right-click → "Kill Process on Port" → Confirm

## 🏗️ Development

### Prerequisites
- **JDK 17**
- **Gradle 8.5+** (wrapper included)
- **IntelliJ IDEA 2024.1+**

### Running in Dev Mode
```bash
./gradlew runIde
```

### Project Structure
```
src/main/kotlin/com/mcc/portforwarder/
├── models/         # Data classes
├── services/       # Business logic
└── toolwindow/     # UI
```

## 📝 License

See LICENSE file.

## 🎉 Credits

Ported from MCCPortForwarder macOS app with full feature parity.
