# 🚀 Quick Start Guide - MCC Port Forwarder Plugin

## 📦 Installation

### 1. Build the Plugin
```bash
cd /Users/max/mcc/mcc-intellij-plugin
./gradlew clean buildPlugin
```

Output: `build/distributions/mcc-intellij-plugin-1.0.0.zip`

### 2. Install in IntelliJ IDEA

**First time or after updates:**
1. **Settings** (⌘,) → **Plugins** → **Installed**
2. If "MCC Port Forwarder" exists → **Uninstall** → **Restart IDE**
3. **Settings** → **Plugins** → **⚙️** → **Install Plugin from Disk...**
4. Select: `mcc-intellij-plugin/build/distributions/mcc-intellij-plugin-1.0.0.zip`
5. **Restart IDE**

### 3. Open Tool Window
- **View** → **Tool Windows** → **MCCPortForwarder**
- Or find **"MCCPortForwarder"** tab on the right side panel

---

## 🎯 Complete Workflow Example

### Step 1: Configure Settings

Click **"⚙️ Settings"** button and configure:

```
Command: /usr/local/bin/mcc tp-port-forward
Login Command: /usr/local/bin/mcc login
Logout Command: /usr/local/bin/mcc logout
Retry Enabled: ✓
Retry Attempts: 3
Retry Delay: 5
Datacenters: dc1, dc2, dc3
```

Click **"Save"**.

---

### Step 2: Create a Service

1. Click **"➕ Add Service"** button on toolbar
2. Enter name: **"Production API"**
3. Click **"OK"**

✅ Service created! (but empty - no hosts yet)

---

### Step 3: Add Host to Service

1. **Right-click** on **"Production API"** service
2. Select **"Add Host"**
3. Fill in the dialog:

```
Host Name: API Server
Hostname Template: api.prod.{location}.example.com
Remote Port: 8080

Select Datacenters:
☑ dc1 → Local Port: 9001
☑ dc2 → Local Port: 9002
☑ dc3 → Local Port: 9003
```

4. Click **"OK"**

✅ Host created with 3 ports!

Tree now shows:
```
📦 Production API
  └─ 🖥️ API Server (3 ports)
      ├─ ⏹️ 9001→8080 [Stopped]
      ├─ ⏹️ 9002→8080 [Stopped]
      └─ ⏹️ 9003→8080 [Stopped]
```

---

### Step 4: Add More Hosts

Repeat Step 3 with different configurations:

**Example 1: Admin Panel**
```
Host Name: Admin Panel
Hostname Template: admin.prod.{location}.example.com
Remote Port: 8081
Datacenters: dc1 (9101), dc2 (9102)
```

**Example 2: Database**
```
Host Name: PostgreSQL
Hostname Template: db.prod.{location}.example.com
Remote Port: 5432
Datacenters: dc1 (5433), dc2 (5434), dc3 (5435)
```

Result:
```
📦 Production API
  ├─ 🖥️ API Server (3 ports)
  ├─ 🖥️ Admin Panel (2 ports)
  └─ 🖥️ PostgreSQL (3 ports)

Total: 8 ports
```

---

### Step 5: Start Port Forwarding

**Method 1: Double-click**
- Double-click on any port: **9001→8080 [Stopped]**
- Status changes: 🔵 Connecting → 🟡 Authenticating → 🟢 Ready

**Method 2: Right-click menu**
- Right-click on port → **"Start"**
- Or right-click on host → **"Start All Ports"**
- Or right-click on service → **"Start Service"**

Watch the status change in real-time:
```
⏹️ Stopped      (not running)
🔵 Connecting   (process started)
🟡 Authenticating (auth in progress)
🟢 Ready        (port forwarding active!)
```

---

### Step 6: Monitor Active Connections

Toolbar shows: **"Active: 3"** (updates in real-time)

This counts only ports in 🟢 **Ready** state.

---

### Step 7: View Logs

1. **Right-click** on any port
2. Select **"View Logs"**
3. See last 50 log lines

Example logs:
```
Executing: mcc tp-port-forward api.prod.dc1.example.com:8080 -p 9001
Authenticating...
Connection established
Proxying connections to api.prod.dc1.example.com:8080
```

---

### Step 8: Stop Port Forwarding

**Method 1: Double-click again**
- Double-click on **🟢 9001→8080 [Ready]**
- Status changes to ⏹️ Stopped

**Method 2: Right-click**
- Right-click → **"Stop"**
- Or stop all: Right-click host → **"Stop All Ports"**

---

### Step 9: Handle Port Conflicts

If port is busy (error: "Port already in use"):

1. **Right-click** on the port
2. Select **"Kill Process on Port"**
3. Confirm: **"Yes"**
4. Process killed (using `lsof` + `kill -9`)
5. Try starting again

---

### Step 10: Edit Host Configuration

Need to change ports or add/remove datacenters?

1. **Right-click** on host (e.g., "API Server")
2. Select **"Edit"**
3. Modify configuration:
   - Change hostname template
   - Change remote port
   - Add/remove datacenters
   - Change local ports
4. Click **"OK"**

✅ Host updated! All ports refreshed.

---

### Step 11: Delete Host or Service

**Delete Host:**
1. **Right-click** on host
2. Select **"Delete"**
3. Confirm
4. All ports stopped automatically
5. Host removed

**Delete Service:**
1. **Right-click** on service
2. Select **"Delete"**
3. Confirm
4. All hosts and ports stopped
5. Service removed

---

## 🎨 Advanced Usage

### Multiple Services

Create separate services for different environments:

```
📦 Production
  ├─ API Server
  └─ Database

📦 Staging
  ├─ Web Server
  └─ Cache

📦 Development
  └─ Dev Server

📦 Monitoring
  ├─ Grafana
  ├─ Prometheus
  └─ Alertmanager
```

### Login / Logout

Before port forwarding, authenticate:

1. Click **"🔐 Login"** button
2. Wait for success message
3. Now you can start ports
4. When done, click **"🚪 Logout"**

### Keyboard Shortcuts

- **Double-click port** = Toggle Start/Stop
- **Right-click** = Context menu
- **⌘,** = Settings

---

## 🐛 Troubleshooting

### Port won't start (stays in "Connecting")

1. Check command in Settings
2. Test in terminal:
   ```bash
   /usr/local/bin/mcc tp-port-forward api.prod.dc1.example.com:8080 -p 9001
   ```
3. View logs (right-click → View Logs)
4. Check permissions

### "Port already in use"

1. Right-click port → **"Kill Process on Port"**
2. Or manually in terminal:
   ```bash
   lsof -ti :9001 | xargs kill -9
   ```

### Plugin not loading

1. Check IntelliJ IDEA version: **2024.1+**
2. Check logs:
   ```bash
   tail -f ~/Library/Logs/JetBrains/IntelliJIdea*/idea.log | grep MCC
   ```
3. Clear caches:
   ```bash
   rm -rf ~/Library/Caches/JetBrains/IntelliJIdea*
   ```
4. Reinstall plugin

### No datacenters in Add Host dialog

1. Click **"⚙️ Settings"**
2. Add datacenters: `dc1, dc2, dc3`
3. Save
4. Try Add Host again

---

## 📊 Configuration Example

Complete example with 3 services:

```
Production API (2 hosts, 5 ports)
├─ API Server
│  ├─ dc1: 9001 → api.prod.dc1.example.com:8080
│  ├─ dc2: 9002 → api.prod.dc2.example.com:8080
│  └─ dc3: 9003 → api.prod.dc3.example.com:8080
└─ Admin Panel
   ├─ dc1: 9101 → admin.prod.dc1.example.com:8081
   └─ dc2: 9102 → admin.prod.dc2.example.com:8081

Monitoring (2 hosts, 5 ports)
├─ Grafana
│  ├─ dc1: 4001 → grafana.dc1.example.com:3000
│  ├─ dc2: 4002 → grafana.dc2.example.com:3000
│  └─ dc3: 4003 → grafana.dc3.example.com:3000
└─ Prometheus
   ├─ dc1: 9091 → prometheus.dc1.example.com:9090
   └─ dc2: 9092 → prometheus.dc2.example.com:9090

Development (1 host, 1 port)
└─ Dev Server
   └─ dc1: 3001 → dev.dc1.example.com:3000
```

Total: **3 services, 5 hosts, 11 ports**

---

## 🎉 You're Ready!

You now have full control over port forwarding directly from IntelliJ IDEA!

### Quick Reference:

| Action | How |
|--------|-----|
| Create Service | ➕ Add Service button |
| Add Host | Right-click service → Add Host |
| Start Port | Double-click or right-click → Start |
| Stop Port | Double-click or right-click → Stop |
| View Logs | Right-click port → View Logs |
| Kill Process | Right-click port → Kill Process |
| Edit | Right-click → Edit |
| Delete | Right-click → Delete |
| Settings | ⚙️ Settings button |
| Login/Logout | 🔐/🚪 buttons |

**Happy port forwarding!** 🚀

