//
//  PortMapping.swift
//  MCCPortForwarder
//

import Foundation

struct PortMapping: Identifiable, Codable, Hashable {
    let id: UUID
    var fromPort: Int
    var toPort: Int
    
    init(id: UUID = UUID(), fromPort: Int, toPort: Int) {
        self.id = id
        self.fromPort = fromPort
        self.toPort = toPort
    }
    
    var displayString: String {
        "\(fromPort) → \(toPort)"
    }
}

