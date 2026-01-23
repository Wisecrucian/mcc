//
//  Service.swift
//  MCCPortForwarder
//

import Foundation

struct Host: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var hostname: String
    var ports: [PortMapping]
    
    init(id: UUID = UUID(), name: String, hostname: String, ports: [PortMapping] = []) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.ports = ports
    }
    
    // Generate unique ID for each port process
    func processId(for port: PortMapping) -> UUID {
        // Create deterministic UUID based on host ID and port ID
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

