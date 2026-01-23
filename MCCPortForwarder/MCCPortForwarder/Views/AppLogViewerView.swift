//
//  AppLogViewerView.swift
//  MCCPortForwarder
//

import SwiftUI

struct AppLogViewerView: View {
    
    @ObservedObject var appLogService: AppLogService
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Application Logs")
                    .font(.system(size: 16, weight: .semibold))
                
                Spacer()
                
                Text("\(appLogService.logs.count) entries")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            Divider()
            
            // Logs
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(appLogService.logs) { entry in
                            AppLogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(12)
                }
                .background(Color(NSColor.textBackgroundColor))
                .onChange(of: appLogService.logs.last?.id) { newId in
                    if autoScroll, let newId = newId {
                        withAnimation {
                            proxy.scrollTo(newId, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Footer
            HStack(spacing: 12) {
                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                
                Spacer()
                
                Button("Clear Logs") {
                    appLogService.clear()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - App Log Entry Row

struct AppLogEntryRow: View {
    
    let entry: AppLogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                // Timestamp
                Text(entry.formattedTimestamp)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 60, alignment: .leading)
                
                // Level emoji
                Text(entry.level.emoji)
                    .font(.system(size: 12))
                
                // Message
                Text(entry.message)
                    .font(.system(size: 11))
                    .foregroundColor(colorForLevel(entry.level))
                    .fixedSize(horizontal: false, vertical: true)
                
                Spacer()
                
                // Expand button if has details
                if entry.details != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Details (if expanded)
            if isExpanded, let details = entry.details {
                Text(details)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
                    .padding(.leading, 76)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(backgroundColorForLevel(entry.level))
        .cornerRadius(6)
    }
    
    private func colorForLevel(_ level: AppLogLevel) -> Color {
        switch level {
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
    
    private func backgroundColorForLevel(_ level: AppLogLevel) -> Color {
        switch level {
        case .info: return Color.clear
        case .warning: return Color.orange.opacity(0.05)
        case .error: return Color.red.opacity(0.05)
        case .success: return Color.green.opacity(0.05)
        }
    }
}

