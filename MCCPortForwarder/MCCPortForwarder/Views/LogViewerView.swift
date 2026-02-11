//
//  LogViewerView.swift
//  MCCPortForwarder
//

import SwiftUI

struct LogViewerView: View {
    
    let hostId: UUID
    let hostName: String
    @ObservedObject var logService: LogService
    @Environment(\.dismiss) private var dismiss
    
    @State private var autoScroll = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Logs content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(logService.getLogs(hostId: hostId)) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: logService.logs[hostId]?.count) { _ in
                    if autoScroll, let lastLog = logService.getLogs(hostId: hostId).last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 700, height: 500)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Logs: \(hostName)")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(logService.getLogs(hostId: hostId).count) entries")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("Auto-scroll", isOn: $autoScroll)
                .toggleStyle(.switch)
                .controlSize(.small)
            
            Button("Clear") {
                logService.clearLogs(hostId: hostId)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            Text("Logs are kept for the last 1000 entries per host")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

// MARK: - Log Entry Row

struct LogEntryRow: View {
    
    let entry: LogEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(entry.formattedTimestamp)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Type indicator
            Circle()
                .fill(entry.isError ? Color.red : Color.green)
                .frame(width: 6, height: 6)
                .padding(.top, 4)
            
            // Message
            Text(entry.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(entry.isError ? .red : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }
}

