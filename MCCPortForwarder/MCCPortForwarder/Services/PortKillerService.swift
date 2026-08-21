//
//  PortKillerService.swift
//  MCCPortForwarder
//

import Foundation

struct PortProcessInfo {
    let pid: Int
    let processName: String
    let port: Int
}

// Stateless: every method shells out to `lsof`/`kill` independently, nothing shared to race on.
final class PortKillerService: Sendable {
    
    // Find process using a specific port
    func findProcessOnPort(_ port: Int) -> PortProcessInfo? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-i", ":\(port)", "-sTCP:LISTEN"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            // Parse lsof output
            let lines = output.components(separatedBy: .newlines)
            for line in lines where !line.isEmpty && !line.hasPrefix("COMMAND") {
                let components = line.split(separator: " ", omittingEmptySubsequences: true)
                if components.count >= 2 {
                    let processName = String(components[0])
                    if let pid = Int(components[1]) {
                        return PortProcessInfo(
                            pid: pid,
                            processName: processName,
                            port: port
                        )
                    }
                }
            }
        } catch {
            print("Error finding process on port \(port): \(error)")
        }
        
        return nil
    }
    
    // Kill process by PID
    func killProcess(pid: Int, force: Bool = false) -> Bool {
        let signal = force ? SIGKILL : SIGTERM
        let result = kill(pid_t(pid), signal)
        return result == 0
    }
    
    // Find and kill process on port
    func killProcessOnPort(_ port: Int, force: Bool = false) -> (success: Bool, message: String) {
        guard let processInfo = findProcessOnPort(port) else {
            return (false, "No process found on port \(port)")
        }
        
        let success = killProcess(pid: processInfo.pid, force: force)
        
        if success {
            let signalType = force ? "SIGKILL" : "SIGTERM"
            return (true, "Killed process '\(processInfo.processName)' (PID: \(processInfo.pid)) using \(signalType)")
        } else {
            return (false, "Failed to kill process '\(processInfo.processName)' (PID: \(processInfo.pid))")
        }
    }
    
    // Check if port is in use
    func isPortInUse(_ port: Int) -> Bool {
        return findProcessOnPort(port) != nil
    }
    
    // Get all listening ports
    func getAllListeningPorts() -> [PortProcessInfo] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        process.arguments = ["-iTCP", "-sTCP:LISTEN", "-n", "-P"]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        
        var ports: [PortProcessInfo] = []
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }
            
            let lines = output.components(separatedBy: .newlines)
            for line in lines where !line.isEmpty && !line.hasPrefix("COMMAND") {
                let components = line.split(separator: " ", omittingEmptySubsequences: true)
                if components.count >= 9 {
                    let processName = String(components[0])
                    if let pid = Int(components[1]) {
                        // Extract port from address (e.g., "*:8080")
                        let address = String(components[8])
                        if let portString = address.split(separator: ":").last,
                           let port = Int(portString) {
                            ports.append(PortProcessInfo(
                                pid: pid,
                                processName: processName,
                                port: port
                            ))
                        }
                    }
                }
            }
        } catch {
            print("Error getting listening ports: \(error)")
        }
        
        return ports
    }
}

