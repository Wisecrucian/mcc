//
//  ConfigurationExport.swift
//  MCCPortForwarder
//

import Foundation

/// Complete application configuration for import/export (without UUIDs)
struct ConfigurationExport: Codable {
    var version: String = "1.0"
    var exportDate: Date = Date()
    var services: [ServiceExport]
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
    
    /// Service without UUID - only user data
    struct ServiceExport: Codable {
        var name: String
        var hosts: [HostExport]
        var childServices: [ServiceExport]
    }
    
    /// Host without UUID - only user data
    struct HostExport: Codable {
        var name: String
        var hostnameTemplate: String
        var remotePort: Int
        var locations: [LocationExport]
    }
    
    /// Location without UUID - only user data
    struct LocationExport: Codable {
        var datacenter: String
        var localPort: Int
    }
}

// MARK: - Conversion Extensions

extension ConfigurationExport.ServiceExport {
    /// Convert from full Service model (strips UUIDs)
    init(from service: Service) {
        self.name = service.name
        self.hosts = service.hosts.map { ConfigurationExport.HostExport(from: $0) }
        self.childServices = service.childServices.map { ConfigurationExport.ServiceExport(from: $0) }
    }
    
    /// Convert to full Service model (generates new UUIDs)
    func toService() -> Service {
        Service(
            name: name,
            hosts: hosts.map { $0.toHost() },
            childServices: childServices.map { $0.toService() }
        )
    }
}

extension ConfigurationExport.HostExport {
    /// Convert from full Host model (strips UUIDs)
    init(from host: Host) {
        self.name = host.name
        self.hostnameTemplate = host.hostnameTemplate
        self.remotePort = host.remotePort
        self.locations = host.locations.map { ConfigurationExport.LocationExport(from: $0) }
    }
    
    /// Convert to full Host model (generates new UUIDs)
    func toHost() -> Host {
        Host(
            name: name,
            hostnameTemplate: hostnameTemplate,
            remotePort: remotePort,
            locations: locations.map { $0.toLocation() }
        )
    }
}

extension ConfigurationExport.LocationExport {
    /// Convert from full LocationMapping model (strips UUIDs)
    init(from location: LocationMapping) {
        self.datacenter = location.datacenter
        self.localPort = location.localPort
    }
    
    /// Convert to full LocationMapping model (generates new UUIDs)
    func toLocation() -> LocationMapping {
        LocationMapping(
            datacenter: datacenter,
            localPort: localPort
        )
    }
}

