//
//  Service.swift
//  MCCPortForwarder
//

import Foundation

struct Host: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var hostnameTemplate: String  // Can contain {location} placeholder
    var remotePort: Int            // Remote port on server (e.g., 5432)
    var locations: [LocationMapping] // Datacenters with local ports
    
    // Legacy fields for migration (will be removed later)
    var hostname: String?
    var tag: String?
    var ports: [PortMapping]?
    
    // New initializer with locations
    init(id: UUID = UUID(), 
         name: String, 
         hostnameTemplate: String, 
         remotePort: Int,
         locations: [LocationMapping] = []) {
        self.id = id
        self.name = name
        self.hostnameTemplate = hostnameTemplate
        self.remotePort = remotePort
        self.locations = locations
        
        // Legacy fields
        self.hostname = nil
        self.tag = nil
        self.ports = nil
    }
    
    // Legacy initializer (for backward compatibility)
    init(id: UUID = UUID(), name: String, hostname: String, tag: String? = nil, ports: [PortMapping] = []) {
        self.id = id
        self.name = name
        self.hostnameTemplate = hostname  // Use as template
        self.remotePort = ports.first?.toPort ?? 5432  // Default
        self.locations = []
        
        // Store legacy fields
        self.hostname = hostname
        self.tag = tag
        self.ports = ports
    }
    
    // Helper: Resolve hostname for a specific location
    func resolvedHostname(for location: LocationMapping) -> String {
        hostnameTemplate.replacingOccurrences(of: "{location}", with: location.datacenter)
    }
    
    // Generate unique ID for each location process
    func processId(for location: LocationMapping) -> UUID {
        location.processId(forHost: id)
    }
    
    // MARK: - Legacy Compatibility (for migration)
    
    // Check if this host uses new structure
    var usesNewStructure: Bool {
        !locations.isEmpty
    }
    
    // Get ports - returns legacy ports or converts locations to ports
    var compatiblePorts: [PortMapping] {
        if let legacyPorts = ports, !legacyPorts.isEmpty {
            return legacyPorts
        }
        // Convert locations to PortMapping format for compatibility
        return locations.map { location in
            PortMapping(fromPort: location.localPort, toPort: remotePort)
        }
    }
    
    // Get hostname - returns legacy or template
    var compatibleHostname: String {
        hostname ?? hostnameTemplate
    }
    
    // Process ID for legacy port mapping
    func processId(for port: PortMapping) -> UUID {
        // If using new structure, find matching location
        if usesNewStructure {
            if let location = locations.first(where: { $0.localPort == port.fromPort }) {
                return processId(for: location)
            }
        }
        // Legacy: deterministic UUID based on host ID and port ID
        let combined = "\(id.uuidString)-\(port.id.uuidString)"
        return UUID(uuidString: combined.md5Hash().prefix(36).padding(toLength: 36, withPad: "0", startingAt: 0)) ?? port.id
    }
}

// Helper for UUID generation
extension String {
    func md5Hash() -> String {
        // Simple hash for demo - in production use CryptoKit
        let hash = self.utf8.reduce(0) { ($0 &+ UInt64($1)) &* 31 }
        return String(format: "%016llx%016llx", hash, hash)
    }
}

struct Service: Identifiable, Codable {
    let id: UUID
    var name: String
    var hosts: [Host]
    var childServices: [Service] // Hierarchical structure
    
    init(id: UUID = UUID(), name: String, hosts: [Host] = [], childServices: [Service] = []) {
        self.id = id
        self.name = name
        self.hosts = hosts
        self.childServices = childServices
    }
    
    // Helper: Get all hosts recursively
    var allHosts: [Host] {
        var result = hosts
        for child in childServices {
            result.append(contentsOf: child.allHosts)
        }
        return result
    }
    
    // Helper: Count total hosts recursively
    var totalHostCount: Int {
        hosts.count + childServices.reduce(0) { $0 + $1.totalHostCount }
    }
}

