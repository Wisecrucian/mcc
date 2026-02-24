//
//  ProcessState.swift
//  MCCPortForwarder
//

import Foundation

enum ProcessState: String, Codable {
    case stopped
    case connecting
    case authenticating
    case ready
    case error
    case timeout
    case portInUse
    case restarting
    case disconnected
    
    var displayName: String {
        switch self {
        case .stopped: return "Stopped"
        case .connecting: return "Connecting"
        case .authenticating: return "Authenticating"
        case .ready: return "Ready"
        case .error: return "Error"
        case .timeout: return "Timeout"
        case .portInUse: return "Port Busy"
        case .restarting: return "Restarting"
        case .disconnected: return "Disconnected"
        }
    }
    
    var emoji: String {
        switch self {
        case .stopped: return "⚪"
        case .connecting: return "🔵"
        case .authenticating: return "🟡"
        case .ready: return "🟢"
        case .error: return "🔴"
        case .timeout: return "🟠"
        case .portInUse: return "🟠"
        case .restarting: return "🔄"
        case .disconnected: return "🟣"
        }
    }
    
    /// Check if this is an active state (process should be running)
    var isActive: Bool {
        switch self {
        case .connecting, .authenticating, .ready, .restarting:
            return true
        case .stopped, .error, .timeout, .portInUse, .disconnected:
            return false
        }
    }
    
    /// Priority for aggregated status (higher = worse)
    var priority: Int {
        switch self {
        case .stopped: return 0
        case .ready: return 1
        case .connecting: return 2
        case .authenticating: return 3
        case .restarting: return 4
        case .disconnected: return 5
        case .timeout: return 6
        case .portInUse: return 7
        case .error: return 8
        }
    }
}

// MARK: - Log Pattern Matching

extension ProcessState {
    /// Patterns to detect state from logs
    enum LogPattern {
        static let ready = [
            "Proxying connections to",
            "Forwarding from",
            "established",
            "Successfully forwarded"
        ]
        
        static let authenticating = [
            "authentication",
            "Authenticating",
            "login",
            "authorizing",
            "credentials",
            "Opening browser"
        ]
        
        static let error = [
            "error:",
            "Error:",
            "failed:",
            "Failed:",
            "refused",
            "Connection refused",
            "denied",
            "Permission denied",
            "cannot connect",
            "Could not resolve"
        ]
        
        static let timeout = [
            "timeout",
            "timed out",
            "Timeout",
            "no response"
        ]
        
        static let portInUse = [
            "address already in use",
            "bind: address already in use",
            "port is already allocated",
            "Address in use"
        ]
    }
    
    /// Determine state from log message
    static func fromLogMessage(_ message: String) -> ProcessState? {
        let lowercased = message.lowercased()
        
        // Check patterns in priority order
        if LogPattern.portInUse.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .portInUse
        }
        
        if LogPattern.error.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .error
        }
        
        if LogPattern.timeout.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .timeout
        }
        
        if LogPattern.ready.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .ready
        }
        
        if LogPattern.authenticating.contains(where: { lowercased.contains($0.lowercased()) }) {
            return .authenticating
        }
        
        return nil
    }
}

