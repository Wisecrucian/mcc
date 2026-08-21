//
//  VersionLookupService.swift
//  MCCPortForwarder
//

import Foundation

/// Shells out to `mcc tool_status -t instance <name>` to find the deployed version of a
/// specific instance. Only makes sense for locations that came from a pasted instance
/// identifier (LocationMapping.sourceInstanceName) — manually-configured ones have no real
/// name to query.
final class VersionLookupService {

    enum LookupError: LocalizedError {
        case invalidBinary
        case emptyOutput
        case versionNotFound
        case processFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidBinary: return "mcc binary not found"
            case .emptyOutput: return "mcc returned no output"
            case .versionNotFound: return "no \"version:\" line in mcc output"
            case .processFailed(let details): return details
            }
        }
    }

    /// - Parameter mccCommand: the configured tp-port-forward command string, from which the
    ///   `mcc` binary path is extracted the same way ProcessService does when launching it.
    func fetchInstanceVersion(
        instanceName: String,
        mccCommand: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let mccPath = ShellEnvironment.binaryPath(fromCommand: mccCommand) else {
            completion(.failure(LookupError.invalidBinary))
            return
        }

        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: mccPath)
            process.arguments = ["tool_status", "-t", "instance", instanceName]

            var environment = ProcessInfo.processInfo.environment
            if let shellPath = ShellEnvironment.resolvedPATH() {
                environment["PATH"] = shellPath
            }
            process.environment = environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                guard process.terminationStatus == 0 else {
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorText = String(data: errorData, encoding: .utf8) ?? ""
                    completion(.failure(LookupError.processFailed(errorText.isEmpty ? "exit code \(process.terminationStatus)" : errorText)))
                    return
                }

                guard !output.isEmpty else {
                    completion(.failure(LookupError.emptyOutput))
                    return
                }

                if let version = Self.extractVersion(from: output) {
                    completion(.success(version))
                } else {
                    completion(.failure(LookupError.versionNotFound))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    // Best-effort: looks for a "version:" (or "version=") key on its own line, whatever
    // surrounds it. This is provisional — written without a real sample of `mcc tool_status`
    // output, so tighten it once we've seen the actual format.
    static func extractVersion(from output: String) -> String? {
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lowercased = trimmed.lowercased()
            guard lowercased.hasPrefix("version:") || lowercased.hasPrefix("version=") else { continue }

            let value = trimmed
                .dropFirst("version:".count)
                .trimmingCharacters(in: CharacterSet(charactersIn: ":= \t\"'"))
            if !value.isEmpty {
                return value
            }
        }
        return nil
    }
}
