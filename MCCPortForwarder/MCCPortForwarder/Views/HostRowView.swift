//
//  HostRowView.swift
//  MCCPortForwarder
//

import SwiftUI

struct HostRowView: View {
    
    let host: Host
    let state: ProcessState
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onLogs: () -> Void
    let onDelete: () -> Void
    let onKillPort: ((PortMapping) -> Void)?
    
    @State private var portToKill: PortMapping? = nil
    let getPortState: (PortMapping) -> ProcessState
    let onTogglePort: (PortMapping) -> Void
    let onShowLogs: (UUID, String) -> Void
    
    @State private var isExpanded = false
    
    private var isRunning: Bool {
        state.isActive || state == .ready
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hostHeader
            
            if isExpanded {
                portsList
            }
        }
        .confirmationDialog(
            portToKill.map { "Kill process on local port \($0.toPort)?" } ?? "",
            isPresented: Binding(
                get: { portToKill != nil },
                set: { if !$0 { portToKill = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Kill Process", role: .destructive) {
                if let port = portToKill, let killAction = onKillPort {
                    killAction(port)
                    portToKill = nil
                }
            }
            Button("Cancel", role: .cancel) {
                portToKill = nil
            }
        } message: {
            if let port = portToKill {
                Text(verbatim: "This will terminate any process using local port \(String(port.toPort))")
            }
        }
    }
    
    private var hostHeader: some View {
        HStack(spacing: 8) {
                // Expand/collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                }
                .buttonStyle(.plain)
                
                // Status indicator (aggregate)
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                
                // Host info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(host.name)
                            .font(.system(size: 12, weight: .medium))
                        
                        // Tag badge
                        if let tag = host.tag, !tag.isEmpty {
                            Text(tag)
                                .font(.system(size: 9, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(host.compatibleHostname)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Ports count
                Text("\(host.compatiblePorts.count) mapping\(host.compatiblePorts.count == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                
                // Aggregate state label
                Text(state.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .trailing)
                
                // Logs button (all logs)
                Button(action: onLogs) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("View all logs")
                
                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Edit host")
                
                // Toggle all button
                Button(action: onToggle) {
                    Image(systemName: isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundColor(isRunning ? .red : .green)
                }
                .buttonStyle(.plain)
                .help(isRunning ? "Stop all port mappings" : "Start all port mappings")
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete host")
            }
            .padding(.vertical, 4)
            .padding(.leading, 16)
    }
    
    @ViewBuilder
    private var portsList: some View {
        if !host.compatiblePorts.isEmpty {
            VStack(spacing: 2) {
                ForEach(host.compatiblePorts) { port in
                    let processId = host.processId(for: port)
                    let matchedLocation = host.usesNewStructure
                        ? host.locations.first(where: { $0.localPort == port.toPort })
                        : nil
                    let resolvedPortHostname = matchedLocation.map(host.resolvedHostname(for:)) ?? host.compatibleHostname
                    let instanceSuffix = matchedLocation.flatMap(host.instanceLabel(for:)).map { " · \($0)" } ?? ""
                    let portName = "\(resolvedPortHostname)\(instanceSuffix) - Port \(String(port.fromPort))→\(String(port.toPort))"
                    PortRowView(
                        host: host,
                        port: port,
                        state: getPortState(port),
                        onToggle: { onTogglePort(port) },
                        onLogs: { 
                            onShowLogs(processId, portName)
                        },
                        onKillPort: onKillPort != nil ? {
                            portToKill = port
                        } : nil
                    )
                }
            }
            .padding(.top, 4)
        }
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
}

