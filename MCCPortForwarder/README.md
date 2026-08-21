# MCC Port Forwarder

A macOS menu bar app for running `mcc tp-port-forward` connections without juggling a pile of terminal tabs. Lives in the menu bar, no dock icon, no window until you click the icon.

## Requirements

- macOS 13+
- the `mcc` CLI installed (default path `/usr/local/bin/mcc`, changeable in Settings)
- to build from source: Xcode 15+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build & run

```bash
make setup   # generates the .xcodeproj from project.yml (first time, or after project.yml changes)
make run     # builds Debug and launches it
```

`make build` + `make install` builds Release and copies it to `/Applications`.

## How it's organized

- **Services** are just a grouping, and can be nested (e.g. "Production" → "Database").
- **Hosts** live inside a service. A host has a name, a hostname template, and a remote port.
- A host can target several **datacenters** at once (the datacenter list itself is managed once in Settings). Each datacenter can have more than one **instance** — useful if there are several replicas behind it. Every instance gets its own local port, and its own hostname resolved from the template via `{location}` and `{instance}`.

Example: template `db.{location}.internal`, remote port `5432`, datacenter `dc1` with 2 instances gives you two independent tunnels:
```
db.dc1.internal:5432 -p 9999    (instance 1)
db.dc1.internal:5432 -p 10000   (instance 2)
```

## Using it day to day

1. Add a service, add a host inside it.
2. Pick which datacenters this host uses, and how many instances per datacenter — ports get auto-assigned, you can tweak them.
3. Hit play on a host or a whole service. Each datacenter/instance runs as its own process with its own status dot and its own logs (click the log icon to see them).
4. If a local port is already taken by something else, the app tells you and offers to kill the process holding it.
5. Login/Logout at the bottom run the `mcc login` / `mcc logout` commands — also configurable in Settings.

Everything is saved automatically after every change (`~/Library/Preferences/com.mcc.portforwarder.plist`). Use Import/Export to back up your config or hand it to a teammate.

## Settings

- path to the `mcc` binary, and the login/logout commands
- auto-retry: attempts and delay before retrying a failed connection
- the datacenter list used when adding/editing hosts

## More docs

- [QUICKSTART.md](QUICKSTART.md) — step-by-step walkthrough
- [ARCHITECTURE.md](ARCHITECTURE.md) — how it's built, for anyone touching the code
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- [CHANGELOG.md](CHANGELOG.md)
