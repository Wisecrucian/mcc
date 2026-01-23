# Usage Examples

Real-world scenarios for MCC Port Forwarder.

---

## Example 1: Development Environment

### Scenario
You're working on a web app with multiple backend services. You need to connect to development database, Redis, and API gateway.

### Setup

**Service**: Development

| Host Name | Hostname |
|-----------|----------|
| Dev PostgreSQL | dev-db.company.com |
| Dev Redis | dev-redis.company.com |
| Dev API | dev-api.company.com |

### Usage

```bash
# Morning routine
1. Click status bar icon
2. Click "Start" next to "Development"
3. Wait for 3 green dots
4. Start coding
```

### Result

```bash
# Verify connections
lsof -i -P | grep mcc
# Shows 3 processes forwarding ports
```

---

## Example 2: Multi-Environment Testing

### Scenario
QA engineer needs to test feature across multiple environments (dev, staging, production).

### Setup

**Service**: Development  
- Dev DB: `dev-db.company.com`
- Dev API: `dev-api.company.com`

**Service**: Staging  
- Staging DB: `staging-db.company.com`
- Staging API: `staging-api.company.com`

**Service**: Production  
- Prod DB (read-only): `prod-db-readonly.company.com`

### Usage

```bash
# Test on dev
1. Start Service: Development
2. Run test suite
3. Stop Service: Development

# Test on staging
4. Start Service: Staging
5. Run test suite
6. Stop Service: Staging

# Verify production data
7. Start Service: Production
8. Query read-only replica
9. Stop Service: Production
```

---

## Example 3: On-Call Debugging

### Scenario
You receive a production alert at 2 AM. Need to quickly connect to production services for debugging.

### Setup

**Service**: Production Emergency

| Host Name | Hostname | Purpose |
|-----------|----------|---------|
| Prod DB | prod-db.company.com | Query logs |
| Prod Redis | prod-redis.company.com | Check cache |
| Prod Metrics | prod-metrics.company.com | View dashboards |
| Prod Logs | prod-logs.company.com | Analyze errors |

### Usage

```bash
# Emergency response
1. Wake up, grab laptop
2. Click status bar icon
3. Click "Start All" (pre-configured emergency service)
4. All 4 connections active in 2 seconds
5. Use local tools to investigate
6. Fix issue
7. Click "Stop All"
8. Go back to sleep
```

---

## Example 4: Team Lead Managing Multiple Projects

### Scenario
Engineering manager overseeing 3 projects, each with their own infrastructure.

### Setup

**Service**: Project Alpha
- Alpha DB: `alpha-db.company.com`
- Alpha API: `alpha-api.company.com`

**Service**: Project Beta
- Beta DB: `beta-db.company.com`
- Beta API: `beta-api.company.com`
- Beta Queue: `beta-queue.company.com`

**Service**: Project Gamma
- Gamma DB: `gamma-db.company.com`

### Usage

```bash
# Context switching throughout the day

9:00 AM - Check Alpha progress
1. Start Service: Project Alpha
2. Review database migrations
3. Stop Service: Project Alpha

11:00 AM - Beta code review
4. Start Service: Project Beta
5. Test new feature branch
6. Stop Service: Project Beta

2:00 PM - Gamma data analysis
7. Start Service: Project Gamma
8. Generate reports
9. Stop Service: Project Gamma

5:00 PM - End of day
10. Click "Stop All" to cleanup
```

---

## Example 5: Continuous Connection (All-Day Dev)

### Scenario
Backend developer working on single project all day, needs persistent connections.

### Setup

**Service**: My Project

| Host Name | Hostname |
|-----------|----------|
| Local PostgreSQL | localhost-db.local |
| Docker MySQL | docker-mysql.local |
| Test Redis | test-redis.local |

### Usage

```bash
# Start of workday
1. Open laptop
2. App auto-launches (if login item configured)
3. Click status bar → Start All
4. Connections stay active all day

# Throughout the day
- Connections persist
- No manual management needed
- Status bar shows active count

# End of workday
5. Close laptop (app auto-stops processes)
# OR
5. Click "Stop All" before closing
```

---

## Example 6: Pair Programming Session

### Scenario
Two developers pairing remotely, need identical environment setup.

### Setup (Both Developers)

**Service**: Pair Session

| Host Name | Hostname |
|-----------|----------|
| Shared Dev DB | pair-session-db.company.com |
| Shared Redis | pair-session-redis.company.com |

### Usage

```bash
# Developer A (Host)
1. Create service: "Pair Session"
2. Add hosts (DB + Redis)
3. Export config: defaults export com.mcc.portforwarder ~/pair-config.plist
4. Share file via Slack/Email

# Developer B (Guest)
5. Receive config file
6. Import: defaults import com.mcc.portforwarder ~/pair-config.plist
7. Restart app: killall MCCPortForwarder && open /Applications/MCCPortForwarder.app
8. Click "Start All"

# Both developers now have identical setup
```

---

## Example 7: Database Migration

### Scenario
DevOps engineer performing database migration, needs connections to old and new DB simultaneously.

### Setup

**Service**: Migration

| Host Name | Hostname | Purpose |
|-----------|----------|---------|
| Old DB (Source) | old-db.company.com | Read data |
| New DB (Target) | new-db.company.com | Write data |
| Monitoring | migration-monitor.company.com | Track progress |

### Usage

```bash
# Before migration
1. Start Service: Migration (all 3 hosts)
2. Verify connections: lsof -i -P | grep mcc
3. Run migration script
4. Script connects to localhost ports (forwarded)
5. Monitor progress via third connection

# After migration
6. Verify data integrity
7. Stop Service: Migration
```

---

## Example 8: Freelancer Managing Client Projects

### Scenario
Freelance developer juggling multiple client projects, each with different infrastructure.

### Setup

**Service**: Client A - E-commerce
- Client A DB: `client-a-db.server.com`
- Client A Cache: `client-a-cache.server.com`

**Service**: Client B - SaaS
- Client B Main: `client-b-main.server.com`
- Client B Analytics: `client-b-analytics.server.com`
- Client B Queue: `client-b-queue.server.com`

**Service**: Client C - Mobile Backend
- Client C API: `client-c-api.server.com`

### Usage

```bash
# Monday - Client A
1. Start Service: Client A - E-commerce
2. Work on e-commerce features (4 hours)
3. Stop Service: Client A - E-commerce

# Tuesday - Client B
4. Start Service: Client B - SaaS
5. Implement analytics (6 hours)
6. Stop Service: Client B - SaaS

# Wednesday - Client C
7. Start Service: Client C - Mobile Backend
8. Debug API issues (3 hours)
9. Stop Service: Client C - Mobile Backend

# No confusion, no wrong connections
```

---

## Example 9: Load Testing

### Scenario
Performance engineer load testing application, needs multiple connections to same host.

### Setup

**Service**: Load Test

| Host Name | Hostname |
|-----------|----------|
| Target 1 | test-app.company.com |
| Target 2 | test-app.company.com |
| Target 3 | test-app.company.com |
| Metrics | test-metrics.company.com |

### Usage

```bash
# Setup
1. Add 3 identical hosts pointing to same hostname
   (Each gets unique process ID)
2. Add metrics host for monitoring

# Execute test
3. Start Service: Load Test
4. 4 processes start simultaneously
5. Run load test tool (connects to localhost ports)
6. Monitor metrics via 4th connection
7. Stop Service: Load Test when done
```

---

## Example 10: Security Audit

### Scenario
Security team auditing production access, needs to document all connections.

### Setup

**Service**: Security Audit

| Host Name | Hostname |
|-----------|----------|
| Auth Service | prod-auth.company.com |
| User DB | prod-users.company.com |
| Access Logs | prod-access-logs.company.com |

### Usage

```bash
# Before audit
1. Create "Security Audit" service
2. Add all services under review
3. Export config for documentation:
   defaults export com.mcc.portforwarder ~/audit-$(date +%Y%m%d).plist

# During audit
4. Start Service: Security Audit
5. Perform security checks
6. Document findings

# After audit
7. Stop Service: Security Audit
8. Archive config file for compliance
```

---

## Advanced Usage

### Scripting

```bash
# Start all services from terminal
defaults write com.mcc.portforwarder AutoStartAll -bool true
open /Applications/MCCPortForwarder.app

# Stop all (kill app)
killall MCCPortForwarder
```

### Automation

```bash
# Create service programmatically
defaults write com.mcc.portforwarder services -array-add \
  "<dict><key>name</key><string>Auto Service</string>...</dict>"
```

### Monitoring

```bash
# Check active connections
ps aux | grep "mcc tp-port-forward" | wc -l

# Monitor connection count
watch -n 1 'ps aux | grep "mcc tp-port-forward" | wc -l'
```

---

## Tips & Tricks

### Naming Conventions

**Services**: Environment or project name
- ✅ "Production East", "Dev Environment", "Project Phoenix"
- ❌ "Service 1", "Test", "Temp"

**Hosts**: Service type + environment
- ✅ "PostgreSQL Primary", "Redis Cache Dev", "API Gateway Prod"
- ❌ "db", "server1", "host"

### Organization

**By Environment**:
```
Development
├── Dev DB
├── Dev Cache
└── Dev API

Staging
├── Staging DB
└── Staging API

Production
├── Prod DB (Read-Only)
└── Prod Monitoring
```

**By Project**:
```
E-commerce App
├── Shop DB
├── Inventory DB
└── Payment Gateway

Analytics Platform
├── Clickstream DB
├── Data Warehouse
└── Metrics API
```

### Keyboard Maestro Integration

```applescript
-- Hotkey: ⌘⇧P to toggle popover
tell application "System Events"
    tell process "MCCPortForwarder"
        click menu bar item 1 of menu bar 2
    end tell
end tell
```

---

## Troubleshooting Examples

### Connection Fails

```bash
# 1. Test manually
/usr/local/bin/mcc tp-port-forward your-hostname

# 2. Check if port is already in use
lsof -i :YOUR_PORT

# 3. Verify hostname resolves
ping your-hostname
```

### State Shows Error

```bash
# 1. Check console logs
log show --predicate 'processImagePath contains "MCCPortForwarder"' --last 5m

# 2. Check mcc process
ps aux | grep mcc

# 3. Restart host
Click stop → wait for gray → click start
```

---

## Best Practices

1. **Use descriptive names**: Future-you will thank you
2. **Group by context**: Services = environments or projects
3. **Start only what you need**: Don't "Start All" unnecessarily
4. **Stop when done**: Free up system resources
5. **Export config**: Backup before major changes
6. **Document hostnames**: Keep wiki/README with hostname purposes
7. **Test manually first**: Verify `mcc` command works before adding to app

---

## Real-World Metrics

### Typical Usage (Small Team)

- **Services**: 3-5
- **Hosts per service**: 2-4
- **Active connections**: 5-10 simultaneously
- **Memory usage**: ~15 MB
- **CPU usage**: < 1%

### Heavy Usage (DevOps Engineer)

- **Services**: 10-15
- **Hosts per service**: 3-6
- **Active connections**: 20-30 simultaneously
- **Memory usage**: ~30-40 MB
- **CPU usage**: 1-2%

---

## Questions?

- **Setup issues**: See [QUICKSTART.md](QUICKSTART.md)
- **Technical details**: See [ARCHITECTURE.md](ARCHITECTURE.md)
- **Problems**: See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

