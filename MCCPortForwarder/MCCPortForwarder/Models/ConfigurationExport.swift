//
//  ConfigurationExport.swift
//  MCCPortForwarder
//

import Foundation

/// Complete application configuration for import/export
struct ConfigurationExport: Codable {
    var version: String = "1.0"
    var exportDate: Date = Date()
    var services: [Service]
    var settings: SettingsExport
    
    struct SettingsExport: Codable {
        var command: String
        var loginCommand: String
        var logoutCommand: String
        var retryEnabled: Bool
        var retryAttempts: Int
        var retryDelay: Int
        var datacenters: [String]
    }
}

