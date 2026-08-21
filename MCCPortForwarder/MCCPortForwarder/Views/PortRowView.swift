//
//  PortRowView.swift
//  MCCPortForwarder
//

import SwiftUI

struct PortRowView: View {
    
    let host: Host
    let port: PortMapping
    let state: ProcessState
    let onToggle: () -> Void
    let onLogs: () -> Void
    let onKillPort: (() -> Void)?

    // Version lookup (mcc tool_status) — nil when this location wasn't parsed from a real
    // pasted instance name, so there's nothing to look up.
    let version: String?
    let versionError: String?
    let onRefreshVersion: (() -> Void)?

    // New structure: toPort == localPort, so we can map this port to a specific location.
    private var matchedLocation: LocationMapping? {
        guard host.usesNewStructure else { return nil }
        return host.locations.first(where: { $0.localPort == port.toPort })
    }

    private var resolvedHostname: String {
        // Legacy: compatibleHostname is already a plain hostname (no {location} placeholder).
        matchedLocation.map(host.resolvedHostname(for:)) ?? host.compatibleHostname
    }

    private var instanceLabel: String? {
        matchedLocation.flatMap(host.instanceLabel(for:))
    }

    private var versionBadgeColor: Color {
        if version != nil { return .green }
        if versionError != nil { return .red }
        return .secondary
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                // Actual hostname substituted from {location}/{instance} placeholders
                HStack(spacing: 4) {
                    Text(resolvedHostname)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let instanceLabel {
                        Text(instanceLabel)
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.secondary)
                            .cornerRadius(3)
                    }

                    if let onRefreshVersion {
                        Button(action: onRefreshVersion) {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 7))
                                Text(version ?? (versionError != nil ? "error" : "version?"))
                            }
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(versionBadgeColor.opacity(0.15))
                            .foregroundColor(versionBadgeColor)
                            .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                        .help(versionError ?? "Refresh version (mcc tool_status)")
                    }
                }
                
                // Port mapping info
                HStack(spacing: 2) {
                    Text(verbatim: String(port.fromPort))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 2)
                    
                    Text(verbatim: String(port.toPort))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.08))
                .cornerRadius(6)
            }
            
            Spacer()
            
            // State label
            Text(state.displayName)
                .font(.system(size: 9))
                .foregroundColor(stateTextColor)
                .frame(width: 55, alignment: .trailing)
            
            // Logs button
            Button(action: onLogs) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
            .help("View logs for this port")
            
            // Kill process button
            if let onKillPort = onKillPort {
                Button(action: onKillPort) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Kill process on local port \(port.toPort)")
            }
            
            // Toggle button
            Button(action: onToggle) {
                let isActive = state.isActive || state == .ready
                Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(isActive ? .red : .green)
            }
            .buttonStyle(.plain)
            .help(state.isActive || state == .ready ? "Stop this port" : "Start this port")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 12)
        // Move port line right so it starts after the "catalog" (host header).
        .padding(.leading, 40)
    }
    
    private var statusColor: Color {
        switch state {
        case .stopped:
            return .gray
        case .connecting:
            return .blue
        case .authenticating:
            return .yellow
        case .ready:
            return .green
        case .error:
            return .red
        case .timeout:
            return .orange
        case .portInUse:
            return .orange
        case .restarting:
            return .yellow
        case .disconnected:
            return .purple
        }
    }
    
    private var stateTextColor: Color {
        switch state {
        case .stopped:
            return .secondary
        case .connecting:
            return .blue
        case .authenticating:
            return .yellow
        case .ready:
            return .green
        case .error:
            return .red
        case .timeout:
            return .orange
        case .portInUse:
            return .orange
        case .restarting:
            return .yellow
        case .disconnected:
            return .purple
        }
    }
}

