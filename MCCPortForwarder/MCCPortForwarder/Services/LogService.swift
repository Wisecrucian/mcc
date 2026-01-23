//
//  LogService.swift
//  MCCPortForwarder
//

import Foundation

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let isError: Bool
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

final class LogService: ObservableObject {
    
    @Published private(set) var logs: [UUID: [LogEntry]] = [:]
    
    private let maxLogsPerHost = 1000
    private let queue = DispatchQueue(label: "com.mcc.logservice", attributes: .concurrent)
    
    // MARK: - Public Methods
    
    func addLog(hostId: UUID, message: String, isError: Bool = false) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let entry = LogEntry(
                timestamp: Date(),
                message: message,
                isError: isError
            )
            
            var hostLogs = self.logs[hostId] ?? []
            hostLogs.append(entry)
            
            // Keep only last N logs
            if hostLogs.count > self.maxLogsPerHost {
                hostLogs.removeFirst(hostLogs.count - self.maxLogsPerHost)
            }
            
            DispatchQueue.main.async {
                self.logs[hostId] = hostLogs
            }
        }
    }
    
    func getLogs(hostId: UUID) -> [LogEntry] {
        queue.sync {
            logs[hostId] ?? []
        }
    }
    
    func clearLogs(hostId: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            DispatchQueue.main.async {
                self?.logs.removeValue(forKey: hostId)
            }
        }
    }
    
    func clearAllLogs() {
        queue.async(flags: .barrier) { [weak self] in
            DispatchQueue.main.async {
                self?.logs.removeAll()
            }
        }
    }
}
