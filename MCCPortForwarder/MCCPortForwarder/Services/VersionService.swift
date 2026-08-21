//
//  VersionService.swift
//  MCCPortForwarder
//

import Foundation

final class VersionService {
    static let shared = VersionService()
    
    private init() {}
    
    /// Get application version from build.number file
    func getVersion() -> String {
        // Try to read from bundle resource first
        if let versionURL = Bundle.main.url(forResource: "build", withExtension: "number"),
           let version = try? String(contentsOf: versionURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines),
           !version.isEmpty {
            return version
        }
        
        // Fallback to bundle version if build.number not found
        if let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return bundleVersion
        }
        
        return "Unknown"
    }
    
    /// Get full version string with app name
    func getFullVersionString() -> String {
        let appName = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "MCCPortForwarder"
        let version = getVersion()
        return "\(appName) v\(version)"
    }
}

