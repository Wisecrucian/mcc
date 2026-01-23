//
//  LocationMapping.swift
//  MCCPortForwarder
//

import Foundation

struct LocationMapping: Identifiable, Codable, Hashable {
    let id: UUID
    var datacenter: String  // Reference to global datacenter name (e.g., "dc1", "eu-west")
    var localPort: Int      // Local port on this machine (e.g., 9999)
    
    init(id: UUID = UUID(), datacenter: String, localPort: Int) {
        self.id = id
        self.datacenter = datacenter
        self.localPort = localPort
    }
    
    // Helper: Generate process ID for this location
    func processId(forHost hostId: UUID) -> UUID {
        // Create deterministic UUID based on host ID and location ID
        let combined = "\(hostId.uuidString)-\(id.uuidString)"
        return UUID(uuidString: combined.md5Hash().prefix(36).padding(toLength: 36, withPad: "0", startingAt: 0)) ?? id
    }
}

