//
//  InstanceNameParser.swift
//  MCCPortForwarder
//

import Foundation

/// A pasted-in instance/service identifier, e.g. "2.myservice.dc1", broken into its parts.
struct ParsedInstanceName {
    let raw: String
    let instanceNumber: Int
    let datacenter: String
}

enum InstanceNameParser {
    /// Instance number is always the leading dot-separated segment; the datacenter is whichever
    /// other segment matches one of the datacenters already configured in Settings.
    static func parse(_ raw: String, knownDatacenters: [String]) -> ParsedInstanceName? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(separator: ".").map(String.init)
        guard parts.count >= 2, let instanceNumber = Int(parts[0]) else { return nil }

        guard let datacenter = parts.dropFirst().first(where: { part in
            knownDatacenters.contains { $0.caseInsensitiveCompare(part) == .orderedSame }
        }) else { return nil }

        return ParsedInstanceName(raw: trimmed, instanceNumber: instanceNumber, datacenter: datacenter)
    }

    /// Parses one instance identifier per non-empty line.
    static func parseLines(_ text: String, knownDatacenters: [String]) -> [ParsedInstanceName] {
        text.components(separatedBy: .newlines)
            .compactMap { parse($0, knownDatacenters: knownDatacenters) }
    }
}
