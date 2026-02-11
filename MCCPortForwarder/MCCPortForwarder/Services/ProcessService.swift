//
//  ProcessService.swift
//  MCCPortForwarder
//

import Foundation
import Combine

final class ProcessService: ObservableObject {
    
    // MARK: - Internal State
    
    private enum InternalState {
        case running
        case stopped
    }
    
    // MARK: - Process Info
    
    private struct ProcessInfo {
        let process: Process
        let outputPipe: Pipe
        let errorPipe: Pipe
        var state: InternalState
    }
    
    // MARK: - Properties
    
    private var processes: [UUID: ProcessInfo] = [:]
    private let queue = DispatchQueue(label: "com.mcc.processservice", attributes: .concurrent)
    
    // Log callback
    var onLogOutput: ((UUID, String, Bool) -> Void)?
    
    // MARK: - Public Methods
    
    func startHost(
        _ hostId: UUID,
        command: String,
        hostname: String,
        fromPort: Int,
        toPort: Int,
        retryAttempts: Int = 1,
        retryDelay: Int = 5,
        onRetryAttempt: ((Int) -> Void)? = nil,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // Check if already running
            if let existing = self.processes[hostId], existing.state == .running {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
            }
            
            // Create process
            let process = Process()
            
            // Parse command (first word is executable, rest are args)
            let commandParts = command.split(separator: " ").map(String.init)
            guard let executable = commandParts.first else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ProcessService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid command"])))
                }
                return
            }
            
            process.executableURL = URL(fileURLWithPath: executable)
            
            // Build arguments: [baseArgs...] + hostname:fromPort + -p + toPort
            var arguments = Array(commandParts.dropFirst())
            arguments.append("\(hostname):\(fromPort)")
            arguments.append("-p")
            arguments.append("\(toPort)")
            
            process.arguments = arguments
            
            // Set environment with expanded PATH
            var environment = Foundation.ProcessInfo.processInfo.environment
            if let shellPath = self.getShellPATH() {
                environment["PATH"] = shellPath
            }
            process.environment = environment
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Setup termination handler
            process.terminationHandler = { [weak self] terminatedProcess in
                self?.handleProcessTermination(hostId: hostId, process: terminatedProcess)
            }
            
            do {
                try process.run()
                
                let info = ProcessInfo(
                    process: process,
                    outputPipe: outputPipe,
                    errorPipe: errorPipe,
                    state: .running
                )
                self.processes[hostId] = info
                
                // Log process started
                self.onLogOutput?(
                    hostId,
                    "Process started with PID: \(process.processIdentifier)",
                    false
                )
                
                // Start reading output
                self.readOutput(hostId: hostId, pipe: outputPipe)
                self.readError(hostId: hostId, pipe: errorPipe)
                
                // Monitor process and retry if needed
                if retryAttempts > 1 {
                    self.monitorAndRetry(
                        hostId: hostId,
                        command: command,
                        hostname: hostname,
                        fromPort: fromPort,
                        toPort: toPort,
                        remainingAttempts: retryAttempts - 1,
                        retryDelay: retryDelay,
                        onRetryAttempt: onRetryAttempt,
                        completion: completion
                    )
                }
                
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                // Retry on failure
                if retryAttempts > 1 {
                    self.onLogOutput?(
                        hostId,
                        "Failed to start (attempt \(retryAttempts)): \(error.localizedDescription). Retrying in \(retryDelay)s...",
                        true
                    )
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryDelay)) {
                        // Notify about retry attempt
                        onRetryAttempt?(retryAttempts - 1)
                        
                        self.startHost(
                            hostId,
                            command: command,
                            hostname: hostname,
                            fromPort: fromPort,
                            toPort: toPort,
                            retryAttempts: retryAttempts - 1,
                            retryDelay: retryDelay,
                            onRetryAttempt: onRetryAttempt,
                            completion: completion
                        )
                    }
                } else {
                    self.onLogOutput?(
                        hostId,
                        "Failed to start process: \(error.localizedDescription)",
                        true
                    )
                    
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        }
    }
    
    func stopHost(_ hostId: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  let info = self.processes[hostId],
                  info.process.isRunning else {
                return
            }
            
            let pid = info.process.processIdentifier
            
            // Log graceful termination attempt
            self.onLogOutput?(
                hostId,
                "Sending SIGTERM to process (PID: \(pid))...",
                false
            )
            
            // Graceful termination
            info.process.terminate()
            
            // Force kill after timeout
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if info.process.isRunning {
                    self.onLogOutput?(
                        hostId,
                        "Process did not respond to SIGTERM, sending SIGKILL...",
                        false
                    )
                    kill(info.process.processIdentifier, SIGKILL)
                }
            }
        }
    }
    
    func getHostState(_ hostId: UUID) -> ProcessState {
        queue.sync {
            guard let processInfo = processes[hostId] else {
                return .stopped
            }
            // Convert internal state to external ProcessState
            // ProcessService only knows running or stopped, detailed states managed by AppViewModel
            switch processInfo.state {
            case .running:
                return processInfo.process.isRunning ? .connecting : .stopped
            case .stopped:
                return .stopped
            }
        }
    }
    
    func isProcessRunning(_ hostId: UUID) -> Bool {
        queue.sync {
            if let processInfo = processes[hostId] {
                return processInfo.process.isRunning
            }
            return false
        }
    }
    
    func stopAll() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            for (hostId, _) in self.processes {
                self.stopHost(hostId)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleProcessTermination(hostId: UUID, process: Process) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            if var info = self.processes[hostId] {
                let exitCode = process.terminationStatus
                let terminationReason = process.terminationReason
                info.state = .stopped
                self.processes[hostId] = info
                
                // Log termination
                let reasonText = terminationReason == .exit ? "normal exit" : "uncaught signal"
                let message = exitCode == 0 
                    ? "Process terminated normally (exit code: \(exitCode))"
                    : "Process terminated with error (exit code: \(exitCode), reason: \(reasonText))"
                
                self.onLogOutput?(hostId, message, exitCode != 0)
                
                // Cleanup after short delay
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    self.queue.async(flags: .barrier) {
                        if self.processes[hostId]?.state != .running {
                            self.processes.removeValue(forKey: hostId)
                        }
                    }
                }
            }
        }
    }
    
    private func readOutput(hostId: UUID, pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        
        handle.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty {
                fileHandle.readabilityHandler = nil
                return
            }
            
            if let output = String(data: data, encoding: .utf8) {
                self?.handleOutput(hostId: hostId, output: output, isError: false)
            }
        }
    }
    
    private func readError(hostId: UUID, pipe: Pipe) {
        let handle = pipe.fileHandleForReading
        
        handle.readabilityHandler = { [weak self] fileHandle in
            let data = fileHandle.availableData
            if data.isEmpty {
                fileHandle.readabilityHandler = nil
                return
            }
            
            if let output = String(data: data, encoding: .utf8) {
                self?.handleOutput(hostId: hostId, output: output, isError: true)
            }
        }
    }
    
    private func handleOutput(hostId: UUID, output: String, isError: Bool) {
        // Log output for debugging
        #if DEBUG
        print("[\(hostId)] \(isError ? "ERROR" : "OUTPUT"): \(output)")
        #endif
        
        // Send to log service
        onLogOutput?(hostId, output, isError)
        
        // Update state if error detected
        if isError {
            queue.async(flags: .barrier) { [weak self] in
                if var info = self?.processes[hostId] {
                    info.state = .stopped
                    self?.processes[hostId] = info
                }
            }
        }
    }
    
    // MARK: - Environment Setup
    
    private func getShellPATH() -> String? {
        // Try to get PATH from user's shell configuration
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        // Try common shell configs
        let configFiles = [
            "\(homeDir)/.zshrc",
            "\(homeDir)/.zprofile",
            "\(homeDir)/.bash_profile",
            "\(homeDir)/.bashrc",
            "\(homeDir)/.profile"
        ]
        
        // Common paths to include
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
        
        // Try to extract PATH from shell configs
        for configFile in configFiles {
            if let content = try? String(contentsOfFile: configFile, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    // Look for PATH exports
                    if trimmed.hasPrefix("export PATH=") || trimmed.hasPrefix("PATH=") {
                        // Extract paths from the line
                        if let range = trimmed.range(of: "=") {
                            let pathValue = String(trimmed[range.upperBound...])
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                            
                            // Parse PATH components
                            let paths = pathValue.components(separatedBy: ":")
                            for path in paths {
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
            }
        }
        
        // Also check current system PATH
        if let systemPath = Foundation.ProcessInfo.processInfo.environment["PATH"] {
            let systemPaths = systemPath.components(separatedBy: ":")
            pathComponents.formUnion(systemPaths)
        }
        
        // Build final PATH, filtering out non-existent directories
        let validPaths = pathComponents.filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        
        return validPaths.joined(separator: ":")
    }
    
    // MARK: - Retry Logic
    
    private func monitorAndRetry(
        hostId: UUID,
        command: String,
        hostname: String,
        fromPort: Int,
        toPort: Int,
        remainingAttempts: Int,
        retryDelay: Int,
        onRetryAttempt: ((Int) -> Void)?,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self,
                  var info = self.processes[hostId] else { return }
            
            // Replace termination handler to include retry logic
            info.process.terminationHandler = { [weak self] terminatedProcess in
                // First, handle normal termination
                self?.handleProcessTermination(hostId: hostId, process: terminatedProcess)
                
                // Check if we should retry
                guard let self = self else { return }
                
                let exitCode = terminatedProcess.terminationStatus
                if exitCode != 0 && remainingAttempts > 0 {
                    self.onLogOutput?(
                        hostId,
                        "⚠️ Process failed with exit code \(exitCode). Retrying in \(retryDelay)s... (\(remainingAttempts) attempts remaining)",
                        true
                    )
                    
                    // Retry after delay
                    DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(retryDelay)) {
                        // Notify about retry attempt
                        onRetryAttempt?(remainingAttempts)
                        
                        self.startHost(
                            hostId,
                            command: command,
                            hostname: hostname,
                            fromPort: fromPort,
                            toPort: toPort,
                            retryAttempts: remainingAttempts,
                            retryDelay: retryDelay,
                            onRetryAttempt: onRetryAttempt,
                            completion: { _ in } // Ignore completion for retries
                        )
                    }
                } else if exitCode != 0 {
                    // No more retries
                    self.onLogOutput?(
                        hostId,
                        "❌ Process failed with exit code \(exitCode). No more retry attempts.",
                        true
                    )
                }
            }
            
            // Save updated process info
            self.processes[hostId] = info
        }
    }
}

