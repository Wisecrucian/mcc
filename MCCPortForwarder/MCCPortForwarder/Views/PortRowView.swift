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
    
    @State private var showingKillConfirm = false
    
    var body: some View {
        HStack(spacing: 8) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            
            // Port mapping info
            HStack(spacing: 2) {
                Text("\(port.fromPort)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 2)
                
                Text("\(port.toPort)")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(6)
            
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
                Button(action: {
                    showingKillConfirm = true
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Kill process on local port \(port.toPort)")
                .confirmationDialog(
                    "Kill process on local port \(port.toPort)?",
                    isPresented: $showingKillConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Kill Process", role: .destructive) {
                        onKillPort()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will terminate any process using local port \(port.toPort)")
                }
            }
            
            // Toggle button
            Button(action: onToggle) {
                Image(systemName: state == .running ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(state == .running ? .red : .green)
            }
            .buttonStyle(.plain)
            .help(state == .running ? "Stop this port" : "Start this port")
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 12)
        .padding(.leading, 24)
    }
    
    private var statusColor: Color {
        switch state {
        case .running:
            return .green
        case .stopped:
            return .gray
        case .error:
            return .red
        case .portInUse:
            return .orange
        case .restarting:
            return .yellow
        }
    }
    
    private var stateTextColor: Color {
        switch state {
        case .running:
            return .green
        case .stopped:
            return .secondary
        case .error:
            return .red
        case .portInUse:
            return .orange
        case .restarting:
            return .yellow
        }
    }
}

