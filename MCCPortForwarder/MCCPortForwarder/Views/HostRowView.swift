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
    
    @State private var showingKillConfirm: Int? = nil
    let getPortState: (PortMapping) -> ProcessState
    let onTogglePort: (PortMapping) -> Void
    let onShowLogs: (UUID, String) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Host header
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
                    Image(systemName: state == .running ? "stop.circle.fill" : "play.circle.fill")
                        .foregroundColor(state == .running ? .red : .green)
                }
                .buttonStyle(.plain)
                .help(state == .running ? "Stop all port mappings" : "Start all port mappings")
                
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
            
            // Individual ports (expanded)
            if isExpanded && !host.compatiblePorts.isEmpty {
                VStack(spacing: 2) {
                    ForEach(host.compatiblePorts) { port in
                        let processId = host.processId(for: port)
                        let portName = "\(host.name) - Port \(String(port.fromPort))→\(String(port.toPort))"
                        PortRowView(
                            host: host,
                            port: port,
                            state: getPortState(port),
                            onToggle: { onTogglePort(port) },
                            onLogs: { 
                                onShowLogs(processId, portName)
                            },
                            onKillPort: onKillPort != nil ? {
                                onKillPort?(port)
                            } : nil
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .stopped:
            return .gray
        case .running:
            return .green
        case .error:
            return .red
        case .portInUse:
            return .orange
        case .restarting:
            return .yellow
        }
    }
}

