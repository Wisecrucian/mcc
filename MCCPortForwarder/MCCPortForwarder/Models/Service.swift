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
    
    // Helper: Resolve hostname for a specific location
    func resolvedHostname(for location: LocationMapping) -> String {
        hostnameTemplate.replacingOccurrences(of: "{location}", with: location.datacenter)
    }
    
    // Generate unique ID for each location process
    func processId(for location: LocationMapping) -> UUID {
        location.processId(forHost: id)
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

