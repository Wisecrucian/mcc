//
//  ShellEnvironment.swift
//  MCCPortForwarder
//

import Foundation

/// Resolves a PATH that includes common Homebrew/user-local bin directories and whatever the
/// user's shell rc files export, so `Process` can find CLI tools like `mcc` the same way a
/// terminal would — GUI apps don't inherit the shell's PATH otherwise.
enum ShellEnvironment {
    static func resolvedPATH() -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        let configFiles = [
            "\(homeDir)/.zshrc",
            "\(homeDir)/.zprofile",
            "\(homeDir)/.bash_profile",
            "\(homeDir)/.bashrc",
            "\(homeDir)/.profile"
        ]

        var pathComponents: Set<String> = [
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "\(homeDir)/.local/bin"
        ]

        for configFile in configFiles {
            if let content = try? String(contentsOf: URL(fileURLWithPath: configFile), encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    guard trimmed.hasPrefix("export PATH=") || trimmed.hasPrefix("PATH=") else { continue }
                    guard let range = trimmed.range(of: "=") else { continue }

                    let pathValue = String(trimmed[range.upperBound...])
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                    for path in pathValue.components(separatedBy: ":") {
                        let cleaned = path
                            .replacingOccurrences(of: "$PATH", with: "")
                            .replacingOccurrences(of: "${PATH}", with: "")
                            .replacingOccurrences(of: "$HOME", with: homeDir)
                            .replacingOccurrences(of: "${HOME}", with: homeDir)
                            .trimmingCharacters(in: .whitespaces)

                        if !cleaned.isEmpty && cleaned != "/" {
                            pathComponents.insert(cleaned)
                        }
                    }
                }
            }
        }

        if let systemPath = ProcessInfo.processInfo.environment["PATH"] {
            pathComponents.formUnion(systemPath.components(separatedBy: ":"))
        }

        let validPaths = pathComponents.filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }

        return validPaths.joined(separator: ":")
    }

    /// First whitespace-separated token of a configured command string — the same convention
    /// ProcessService/AppViewModel already use to split the executable from its base arguments.
    static func binaryPath(fromCommand command: String) -> String? {
        command.split(separator: " ").first.map(String.init)
    }
}
