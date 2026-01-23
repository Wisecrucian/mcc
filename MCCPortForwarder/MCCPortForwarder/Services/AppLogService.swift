//
//  AppLogService.swift
//  MCCPortForwarder
//

import Foundation
import Combine

enum AppLogLevel {
    case info
    case warning
    case error
    case success
    
    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .success: return "✅"
        }
    }
}

struct AppLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let level: AppLogLevel
    let message: String
    let details: String?
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
}

class AppLogService: ObservableObject {
    @Published private(set) var logs: [AppLogEntry] = []
    private let maxLogEntries = 500
    
    func log(_ message: String, level: AppLogLevel = .info, details: String? = nil) {
        DispatchQueue.main.async {
            let entry = AppLogEntry(
                timestamp: Date(),
                level: level,
                message: message,
                details: details
            )
            
            self.logs.append(entry)
            
            // Trim old logs
            if self.logs.count > self.maxLogEntries {
                self.logs.removeFirst(self.logs.count - self.maxLogEntries)
            }
            
            // Also print to console in debug
            #if DEBUG
            print("[\(entry.formattedTimestamp)] \(level.emoji) \(message)")
            if let details = details {
                print("  Details: \(details)")
            }
            #endif
        }
    }
    
    func info(_ message: String, details: String? = nil) {
        log(message, level: .info, details: details)
    }
    
    func warning(_ message: String, details: String? = nil) {
        log(message, level: .warning, details: details)
    }
    
    func error(_ message: String, details: String? = nil) {
        log(message, level: .error, details: details)
    }
    
    func success(_ message: String, details: String? = nil) {
        log(message, level: .success, details: details)
    }
    
    func clear() {
        DispatchQueue.main.async {
            self.logs.removeAll()
        }
    }
}

