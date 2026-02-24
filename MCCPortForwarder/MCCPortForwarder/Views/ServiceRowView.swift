//
//  ServiceRowView.swift
//  MCCPortForwarder
//

import SwiftUI

struct ServiceRowView: View {

    let service: Service
    let state: ProcessState
    let level: Int // For indentation in hierarchy
    @Binding var isExpanded: Bool

    let onStart: () -> Void
    let onStop: () -> Void
    let onEdit: () -> Void
    let onAddHost: () -> Void
    let onAddChildService: () -> Void
    let onEditHost: (Host) -> Void
    let onDeleteHost: (UUID) -> Void
    let onToggleHost: (Host) -> Void
    let onShowLogs: (UUID) -> Void
    let onKillPort: ((Host, PortMapping) -> Void)?
    let onDelete: () -> Void

    let getHostState: (UUID) -> ProcessState
    let getPortState: (Host, PortMapping) -> ProcessState
    let onTogglePort: (Host, PortMapping) -> Void
    let onShowLogsForPort: (UUID, String) -> Void
    let renderChildService: (Service, Int) -> AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Service header
            HStack(spacing: 8) {
                // Indentation
                if level > 0 {
                    ForEach(0..<level, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 2)
                            .padding(.leading, 8)
                    }
                }

                // Expand/collapse button
                Button(action: { isExpanded.toggle() }) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .buttonStyle(.plain)

                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)

                // Service name
                Text(service.name)
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                // Host count (total including children)
                Text("\(service.totalHostCount) hosts")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                // Edit button
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .help("Edit service")

                // Start/Stop buttons
                if state.isActive || state == .ready {
                    Button("Stop") {
                        onStop()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .font(.system(size: 11))
                } else {
                    Button("Start") {
                        onStart()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                }

                // Delete service
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Delete service")
            }
            .padding(.leading, 16 + CGFloat(level * 16))

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    // Hosts
                    ForEach(service.hosts) { host in
                        HostRowView(
                            host: host,
                            state: getHostState(host.id),
                            onToggle: {
                                onToggleHost(host)
                            },
                            onEdit: {
                                onEditHost(host)
                            },
                            onLogs: {
                                onShowLogsForPort(host.id, host.name)
                            },
                            onDelete: {
                                onDeleteHost(host.id)
                            },
                            onKillPort: onKillPort != nil ? { portMapping in
                                onKillPort?(host, portMapping)
                            } : nil,
                            getPortState: { port in
                                getPortState(host, port)
                            },
                            onTogglePort: { port in
                                onTogglePort(host, port)
                            },
                            onShowLogs: onShowLogsForPort
                        )
                        .padding(.leading, CGFloat(level * 16))
                    }

                    // Child services (recursive)
                    ForEach(service.childServices) { childService in
                        renderChildService(childService, level + 1)
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: onAddHost) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("Add Host")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)

                        Button(action: onAddChildService) {
                            HStack {
                                Image(systemName: "folder.badge.plus")
                                Text("Add Sub-Service")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.leading, CGFloat((level + 1) * 16))
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 6)
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

