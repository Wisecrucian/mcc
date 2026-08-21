# mcc

Internal tooling around `mcc` (the internal multi-datacenter port-forwarding CLI).

## Projects

### [MCCPortForwarder](MCCPortForwarder/) — macOS status bar app

The actively maintained project in this repo. A native SwiftUI/AppKit menu-bar utility that
manages multiple `mcc tp-port-forward` connections at once: hierarchical services/hosts,
per-datacenter (and per-instance) local ports, live connection state, auto-retry, and
config import/export.

See [MCCPortForwarder/README.md](MCCPortForwarder/README.md) for setup, architecture, and usage,
and [MCCPortForwarder/CHANGELOG.md](MCCPortForwarder/CHANGELOG.md) for release history.

```bash
cd MCCPortForwarder
make setup && make run
```

### `mcc-intellij-plugin/` — IntelliJ plugin (inactive here)

Was an early IntelliJ IDEA plugin for the same port-forwarding workflow. The directory in this
repo currently holds only stray Gradle cache metadata, not the plugin's source — treat it as
dormant rather than a working project until it's properly restored or removed.

## Other files

- [`IDEAS.md`](IDEAS.md) — design notes and parked ideas that don't belong in either project's
  own docs yet.
