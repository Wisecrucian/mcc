//
//  LocationMapping.swift
//  MCCPortForwarder
//

import Foundation

struct LocationMapping: Identifiable, Codable, Hashable {
    let id: UUID
    var datacenter: String  // Reference to global datacenter name (e.g., "dc1", "eu-west")
    var instance: Int       // 1-based instance number within this datacenter (e.g., 1, 2, 3)
    var localPort: Int      // Local port on this machine (e.g., 9999)

    init(id: UUID = UUID(), datacenter: String, instance: Int = 1, localPort: Int) {
        self.id = id
        self.datacenter = datacenter
        self.instance = instance
        self.localPort = localPort
    }

    // MARK: - Codable (custom, so configs saved before `instance` existed still decode)

    private enum CodingKeys: String, CodingKey {
        case id, datacenter, instance, localPort
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        datacenter = try container.decode(String.self, forKey: .datacenter)
        localPort = try container.decode(Int.self, forKey: .localPort)
        instance = try container.decodeIfPresent(Int.self, forKey: .instance) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(datacenter, forKey: .datacenter)
        try container.encode(instance, forKey: .instance)
        try container.encode(localPort, forKey: .localPort)
    }

    // Helper: Generate process ID for this location
    func processId(forHost hostId: UUID) -> UUID {
        // Create deterministic UUID based on host ID and location ID
        let combined = "\(hostId.uuidString)-\(id.uuidString)"
        return UUID(uuidString: combined.md5Hash().prefix(36).padding(toLength: 36, withPad: "0", startingAt: 0)) ?? id
    }
}

