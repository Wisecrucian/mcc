//
//  ProcessState.swift
//  MCCPortForwarder
//

import Foundation

enum ProcessState: String, Codable {
    case stopped
    case running
    case error
    case portInUse
    
    var displayName: String {
        switch self {
        case .stopped: return "Stopped"
        case .running: return "Running"
        case .error: return "Error"
        case .portInUse: return "Port Busy"
        }
    }
    
    var emoji: String {
        switch self {
        case .stopped: return "⚫"
        case .running: return "🟢"
        case .error: return "🔴"
        case .portInUse: return "🟡"
        }
    }
}

