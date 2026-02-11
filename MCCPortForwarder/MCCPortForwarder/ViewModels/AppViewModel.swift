//
//  AppViewModel.swift
//  MCCPortForwarder
//

import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var services: [Service] = []
    @Published var hostStates: [UUID: ProcessState] = [:]
    @Published var showingLogViewer = false
    @Published var selectedHostForLogs: UUID?
    @Published var selectedLogName: String?
    @Published var showingSettings = false
    @Published var showingAppLogs = false
    @Published var isAuthenticating = false
    @Published var authStatus: String = ""
    
    // MARK: - Services
    
    private let processService = ProcessService()
    private let storageService = StorageService()
    let logService = LogService()
    let settingsService = SettingsService()
    let appLogService = AppLogService()
    private let portKillerService = PortKillerService()
    
    // MARK: - State Tracking
    
    private var stateTimer: Timer?
    // Removed processToHostMapping - not needed anymore, processId is already unique per port
    
    // MARK: - Initialization
    
    init() {
        appLogService.info("MCCPortForwarder starting...")
        loadServices()
        startStateTracking()
        setupLogCapture()
        appLogService.success("Application initialized successfully")
    }
    
    private func setupLogCapture() {
        processService.onLogOutput = { [weak self] processId, message, isError in
            guard let self = self else { return }
            
            // processId is unique per port mapping, use it directly
            // No need to map - logs go to specific port mapping
            DispatchQueue.main.async {
                self.logService.addLog(hostId: processId, message: message, isError: isError)
            }
        }
    }
    
    deinit {
        stateTimer?.invalidate()
        processService.stopAll()
    }
    
    // MARK: - Service Management
    
    func addService(name: String, parentId: UUID? = nil) {
        let service = Service(name: name)
        
        if let parentId = parentId {
            // Add as child service
            addChildService(service, to: parentId, in: &services)
        } else {
            // Add as root service
            services.append(service)
        }
        saveServices()
    }
    
    private func addChildService(_ service: Service, to parentId: UUID, in services: inout [Service]) {
        for index in services.indices {
            if services[index].id == parentId {
                services[index].childServices.append(service)
                return
            }
            addChildService(service, to: parentId, in: &services[index].childServices)
        }
    }
    
    func deleteService(_ service: Service) {
        // Stop all hosts recursively
        stopServiceRecursive(service)
        
        // Remove service
        removeService(service.id, from: &services)
        saveServices()
    }
    
    private func removeService(_ id: UUID, from services: inout [Service]) {
        services.removeAll { $0.id == id }
        for index in services.indices {
            removeService(id, from: &services[index].childServices)
        }
    }
    
    private func stopServiceRecursive(_ service: Service) {
        for host in service.hosts {
            stopHostAllPorts(host)
        }
        for child in service.childServices {
            stopServiceRecursive(child)
        }
    }
    
    func updateService(_ service: Service) {
        updateServiceRecursive(service, in: &services)
        saveServices()
    }
    
    private func updateServiceRecursive(_ service: Service, in services: inout [Service]) {
        for index in services.indices {
            if services[index].id == service.id {
                services[index] = service
                return
            }
            updateServiceRecursive(service, in: &services[index].childServices)
        }
    }
    
    // MARK: - Host Management
    
    // New method for datacenter-based hosts
    func addHostWithLocations(to serviceId: UUID, name: String, hostnameTemplate: String, remotePort: Int, locations: [LocationMapping]) {
        let newHost = Host(name: name, hostnameTemplate: hostnameTemplate, remotePort: remotePort, locations: locations)
        addHostWithLocationsRecursive(to: serviceId, host: newHost, in: &services)
        saveServices()
        
        // Log action
        appLogService.log("Added host '\(name)' with \(locations.count) datacenter(s)", level: .info)
    }
    
    // Legacy method for old-style hosts
    func addHost(to serviceId: UUID, name: String, hostname: String, tag: String? = nil, ports: [PortMapping]) {
        addHostRecursive(to: serviceId, name: name, hostname: hostname, tag: tag, ports: ports, in: &services)
        saveServices()
        
        // Log action - using first host's ID for logging
        if let addedHost = findHostByName(name, in: services) {
            let tagInfo = tag.map { " [Tag: \($0)]" } ?? ""
            logService.addLog(
                hostId: addedHost.id,
                message: "Host '\(name)' added with hostname '\(hostname)'\(tagInfo) and \(ports.count) port(s)",
                isError: false
            )
        }
    }
    
    private func findHostByName(_ name: String, in services: [Service]) -> Host? {
        for service in services {
            if let host = service.hosts.first(where: { $0.name == name }) {
                return host
            }
            if let host = findHostByName(name, in: service.childServices) {
                return host
            }
        }
        return nil
    }
    
    // New recursive helper for location-based hosts
    private func addHostWithLocationsRecursive(to serviceId: UUID, host: Host, in services: inout [Service]) {
        for index in services.indices {
            if services[index].id == serviceId {
                services[index].hosts.append(host)
                return
            }
            addHostWithLocationsRecursive(to: serviceId, host: host, in: &services[index].childServices)
        }
    }
    
    // Legacy recursive helper for old-style hosts
    private func addHostRecursive(to serviceId: UUID, name: String, hostname: String, tag: String?, ports: [PortMapping], in services: inout [Service]) {
        for index in services.indices {
            if services[index].id == serviceId {
                let host = Host(name: name, hostname: hostname, tag: tag, ports: ports)
                services[index].hosts.append(host)
                return
            }
            addHostRecursive(to: serviceId, name: name, hostname: hostname, tag: tag, ports: ports, in: &services[index].childServices)
        }
    }
    
    func deleteHost(_ hostId: UUID, from serviceId: UUID) {
        // Find host to get all ports
        if let host = findHostById(hostId, in: services) {
            logService.addLog(
                hostId: hostId,
                message: "Host deleted - stopping all \(host.compatiblePorts.count) port(s) and clearing logs",
                isError: false
            )
            
            // Stop all ports
            stopHostAllPorts(host)
        }
        
        deleteHostRecursive(hostId, from: serviceId, in: &services)
        logService.clearLogs(hostId: hostId)
        saveServices()
    }
    
    private func findHostById(_ hostId: UUID, in services: [Service]) -> Host? {
        for service in services {
            if let host = service.hosts.first(where: { $0.id == hostId }) {
                return host
            }
            if let host = findHostById(hostId, in: service.childServices) {
                return host
            }
        }
        return nil
    }
    
    private func deleteHostRecursive(_ hostId: UUID, from serviceId: UUID, in services: inout [Service]) {
        for index in services.indices {
            if services[index].id == serviceId {
                services[index].hosts.removeAll { $0.id == hostId }
                return
            }
            deleteHostRecursive(hostId, from: serviceId, in: &services[index].childServices)
        }
    }
    
    // New method for updating hosts with locations
    func updateHostWithLocations(hostId: UUID, in serviceId: UUID, name: String, hostnameTemplate: String, remotePort: Int, locations: [LocationMapping]) {
        guard let serviceIndex = services.firstIndex(where: { findServiceContainingHost(hostId, in: $0) != nil }) else { return }
        
        var updatedHost = Host(id: hostId, name: name, hostnameTemplate: hostnameTemplate, remotePort: remotePort, locations: locations)
        
        updateHostWithLocationsRecursive(updatedHost, in: serviceId, in: &services)
        saveServices()
        
        appLogService.log("Updated host '\(name)' with \(locations.count) datacenter(s)", level: .info)
    }
    
    private func updateHostWithLocationsRecursive(_ host: Host, in serviceId: UUID, in services: inout [Service]) {
        for index in services.indices {
            if services[index].id == serviceId {
                if let hostIndex = services[index].hosts.firstIndex(where: { $0.id == host.id }) {
                    services[index].hosts[hostIndex] = host
                }
                return
            }
            updateHostWithLocationsRecursive(host, in: serviceId, in: &services[index].childServices)
        }
    }
    
    private func findServiceContainingHost(_ hostId: UUID, in service: Service) -> Service? {
        if service.hosts.contains(where: { $0.id == hostId }) {
            return service
        }
        for child in service.childServices {
            if let found = findServiceContainingHost(hostId, in: child) {
                return found
            }
        }
        return nil
    }
    
    // Legacy method for updating hosts
    func updateHost(_ host: Host, in serviceId: UUID) {
        updateHostRecursive(host, in: serviceId, in: &services)
        saveServices()
        
        logService.addLog(
            hostId: host.id,
            message: "Host updated - Name: '\(host.name)', Hostname: '\(host.compatibleHostname)'",
            isError: false
        )
    }
    
    private func updateHostRecursive(_ host: Host, in serviceId: UUID, in services: inout [Service]) {
        for index in services.indices {
            if services[index].id == serviceId {
                if let hostIndex = services[index].hosts.firstIndex(where: { $0.id == host.id }) {
                    services[index].hosts[hostIndex] = host
                }
                return
            }
            updateHostRecursive(host, in: serviceId, in: &services[index].childServices)
        }
    }
    
    // MARK: - Process Control
    
    func startHost(_ host: Host) {
        guard !host.compatiblePorts.isEmpty else {
            logService.addLog(
                hostId: host.id,
                message: "❌ No ports configured for this host",
                isError: true
            )
            appLogService.warning("Cannot start host '\(host.name)': no ports configured")
            return
        }
        
        logService.addLog(
            hostId: host.id,
            message: "⚡ Starting \(host.compatiblePorts.count) port mapping(s) for '\(host.compatibleHostname)'...",
            isError: false
        )
        
        appLogService.info("Starting host '\(host.name)' with \(host.compatiblePorts.count) port(s)", details: "Hostname: \(host.compatibleHostname)")
        
        for port in host.compatiblePorts {
            startHostPort(host: host, port: port)
        }
    }
    
    func startPort(host: Host, port: PortMapping) {
        logService.addLog(
            hostId: host.id,
            message: "⚡ Starting port \(String(port.fromPort)) → \(String(port.toPort))...",
            isError: false
        )
        
        startHostPort(host: host, port: port)
    }
    
    func stopPort(host: Host, port: PortMapping) {
        let processId = host.processId(for: port)
        
        logService.addLog(
            hostId: host.id,
            message: "🛑 Stopping port \(String(port.fromPort)) → \(String(port.toPort))...",
            isError: false
        )
        
        processService.stopHost(processId)
        hostStates[processId] = .stopped
        
        // Update aggregate state
        updateHostAggregateState(host)
        
        logService.addLog(
            hostId: host.id,
            message: "⚫ Port \(String(port.fromPort)) → \(String(port.toPort)) stopped",
            isError: false
        )
    }
    
    func togglePort(host: Host, port: PortMapping) {
        let processId = host.processId(for: port)
        let state = hostStates[processId] ?? .stopped
        
        switch state {
        case .stopped, .error, .portInUse:
            startPort(host: host, port: port)
        case .running, .restarting:
            stopPort(host: host, port: port)
        }
    }
    
    func getPortState(host: Host, port: PortMapping) -> ProcessState {
        let processId = host.processId(for: port)
        return hostStates[processId] ?? .stopped
    }
    
    private func startHostPort(host: Host, port: PortMapping) {
        let processId = host.processId(for: port)
        let command = settingsService.getCommand()
        
        // Resolve hostname with location if using new structure
        let hostname: String
        if host.usesNewStructure {
            // Find the location for this port (toPort = localPort)
            if let location = host.locations.first(where: { $0.localPort == port.toPort }) {
                hostname = host.resolvedHostname(for: location)
            } else {
                hostname = host.compatibleHostname
            }
        } else {
            hostname = host.compatibleHostname
        }
        
        let fullCommand = "\(command) \(hostname):\(port.fromPort) -p \(port.toPort)"
        
        // Register mapping for logs - каждый порт имеет свой уникальный processId и логи
        // processId уникален для каждого port mapping, не переназначаем
        
        // Check if local port (toPort) is already in use
        if portKillerService.isPortInUse(port.toPort) {
            if let processInfo = portKillerService.findProcessOnPort(port.toPort) {
                hostStates[processId] = .portInUse
                
                logService.addLog(
                    hostId: processId,
                    message: "🟡 Local port \(String(port.toPort)) is already in use",
                    isError: true
                )
                
                logService.addLog(
                    hostId: processId,
                    message: "Process using port: \(processInfo.processName) (PID: \(processInfo.pid))",
                    isError: true
                )
                
                appLogService.warning(
                    "Port \(String(port.toPort)) is busy",
                    details: "Host: \(host.name), Mapping: \(String(port.fromPort))→\(String(port.toPort)), Process: \(processInfo.processName) (PID: \(processInfo.pid))"
                )
                
                updateHostAggregateState(host)
                return
            }
        }
        
        logService.addLog(
            hostId: processId,
            message: "🔌 Port \(String(port.fromPort)) → \(String(port.toPort))",
            isError: false
        )
        
        logService.addLog(
            hostId: processId,
            message: "Hostname: \(hostname)",
            isError: false
        )
        
        logService.addLog(
            hostId: processId,
            message: "Command: \(fullCommand)",
            isError: false
        )
        
        let retryEnabled = settingsService.isRetryEnabled()
        let retryAttempts = retryEnabled ? settingsService.getRetryAttempts() : 1
        let retryDelay = settingsService.getRetryDelay()
        
        processService.startHost(
            processId,
            command: command,
            hostname: hostname,
            fromPort: port.fromPort,
            toPort: port.toPort,
            retryAttempts: retryAttempts,
            retryDelay: retryDelay,
            onRetryAttempt: { [weak self] attempt in
                // Set restarting state
                DispatchQueue.main.async {
                    self?.hostStates[processId] = .restarting
                    self?.logService.addLog(
                        hostId: processId,
                        message: "🔄 Retry attempt \(attempt) of \(retryAttempts)...",
                        isError: false
                    )
                }
            }
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                switch result {
                case .success:
                    self?.hostStates[processId] = .running
                    self?.logService.addLog(
                        hostId: processId,
                        message: "✅ Port \(String(port.fromPort)) → \(String(port.toPort)) started successfully",
                        isError: false
                    )
                    self?.updateHostAggregateState(host)
                case .failure(let error):
                    self?.hostStates[processId] = .error
                    self?.logService.addLog(
                        hostId: processId,
                        message: "❌ Port \(String(port.fromPort)) → \(String(port.toPort)) failed: \(error.localizedDescription)",
                        isError: true
                    )
                    self?.updateHostAggregateState(host)
                }
            }
        }
    }
    
    func stopHostAllPorts(_ host: Host) {
        for port in host.compatiblePorts {
            let processId = host.processId(for: port)
            
            logService.addLog(
                hostId: processId,
                message: "🛑 Stopping port \(String(port.fromPort)) → \(String(port.toPort))...",
                isError: false
            )
            
            processService.stopHost(processId)
            hostStates[processId] = .stopped
            
            logService.addLog(
                hostId: processId,
                message: "⚫ Connection stopped",
                isError: false
            )
        }
        
        hostStates[host.id] = .stopped
    }
    
    private func updateHostAggregateState(_ host: Host) {
        let portStates = host.compatiblePorts.map { hostStates[host.processId(for: $0)] ?? .stopped }
        
        if portStates.allSatisfy({ $0 == .running }) {
            hostStates[host.id] = .running
        } else if portStates.contains(.running) {
            hostStates[host.id] = .running
        } else if portStates.contains(.portInUse) {
            hostStates[host.id] = .portInUse
        } else if portStates.contains(.error) {
            hostStates[host.id] = .error
        } else {
            hostStates[host.id] = .stopped
        }
    }
    
    func startService(_ service: Service) {
        // Start all hosts in this service
        for host in service.hosts {
            startHost(host)
        }
        // Start all child services recursively
        for child in service.childServices {
            startService(child)
        }
    }
    
    func stopService(_ service: Service) {
        // Stop all hosts in this service
        for host in service.hosts {
            stopHostAllPorts(host)
        }
        // Stop all child services recursively
        for child in service.childServices {
            stopService(child)
        }
    }
    
    func startAll() {
        for service in services {
            startService(service)
        }
    }
    
    func stopAll() {
        for service in services {
            stopService(service)
        }
    }
    
    func toggleHost(_ host: Host) {
        let state = hostStates[host.id] ?? .stopped
        
        logService.addLog(
            hostId: host.id,
            message: "Toggle requested - Current state: \(state.displayName)",
            isError: false
        )
        
        switch state {
        case .stopped, .error, .portInUse:
            startHost(host)
        case .running, .restarting:
            stopHostAllPorts(host)
        }
    }
    
    // MARK: - State Queries
    
    func getServiceState(_ service: Service) -> ProcessState {
        // Get states of direct hosts
        var states = service.hosts.map { hostStates[$0.id] ?? .stopped }
        
        // Add states from child services
        for child in service.childServices {
            states.append(getServiceState(child))
        }
        
        if states.isEmpty {
            return .stopped
        }
        
        if states.allSatisfy({ $0 == .running }) {
            return .running
        } else if states.contains(.running) {
            return .running
        } else if states.contains(.error) {
            return .error
        } else {
            return .stopped
        }
    }
    
    func getHostState(_ hostId: UUID) -> ProcessState {
        hostStates[hostId] ?? .stopped
    }
    
    // MARK: - Private Methods
    
    private func loadServices() {
        services = storageService.loadServices()
    }
    
    private func saveServices() {
        storageService.saveServices(services)
    }
    
    private func startStateTracking() {
        stateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateHostStates()
            }
        }
    }
    
    private func updateHostStates() {
        updateHostStatesRecursive(services)
    }
    
    private func updateHostStatesRecursive(_ services: [Service]) {
        for service in services {
            for host in service.hosts {
                // Update state for each port
                for port in host.compatiblePorts {
                    let processId = host.processId(for: port)
                    let state = processService.getHostState(processId)
                    hostStates[processId] = state
                }
                // Update aggregate host state
                updateHostAggregateState(host)
            }
            updateHostStatesRecursive(service.childServices)
        }
    }
    
    // MARK: - Log Management
    
    func showLogs(for processId: UUID, name: String? = nil) {
        selectedHostForLogs = processId
        selectedLogName = name
        showingLogViewer = true
    }
    
    func showAppLogs() {
        showingAppLogs = true
    }
    
    // MARK: - Port Management
    
    func killProcessOnPort(_ port: Int, forHost host: Host, portMapping: PortMapping) {
        appLogService.info("Attempting to kill process on port \(port)", details: "Host: \(host.name)")
        
        // Find the specific port mapping process ID for logging
        let processId = host.processId(for: portMapping)
        
        // Run on background thread to avoid blocking UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Check if port is in use
            guard let processInfo = self.portKillerService.findProcessOnPort(port) else {
                DispatchQueue.main.async {
                    self.appLogService.warning("No process found on port \(port)", details: "Host: \(host.name)")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.appLogService.warning(
                    "Found process on port \(port)",
                    details: "Process: \(processInfo.processName) (PID: \(processInfo.pid))"
                )
                
                self.logService.addLog(
                    hostId: processId,
                    message: "🔍 Found process '\(processInfo.processName)' (PID: \(processInfo.pid)) on port \(port)",
                    isError: false
                )
            }
            
            // Try graceful kill first (on background thread)
            let result = self.portKillerService.killProcessOnPort(port, force: false)
            
            DispatchQueue.main.async {
                if result.success {
                    self.appLogService.success("Killed process on port \(port)", details: result.message)
                    self.logService.addLog(
                        hostId: processId,
                        message: "✅ \(result.message)",
                        isError: false
                    )
                    
                    // ✅ Stop the process in ProcessService to prevent auto-restart
                    self.processService.stopHost(processId)
                    self.hostStates[processId] = .stopped
                    self.updateHostAggregateState(host)
                } else {
                    self.appLogService.error("Failed to kill process on port \(port)", details: result.message)
                    self.logService.addLog(
                        hostId: processId,
                        message: "❌ \(result.message)",
                        isError: true
                    )
                    
                    // Offer force kill after delay
                    DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) {
                        if self.portKillerService.isPortInUse(port) {
                            let forceResult = self.portKillerService.killProcessOnPort(port, force: true)
                            DispatchQueue.main.async {
                                if forceResult.success {
                                    self.appLogService.warning("Force killed process on port \(port)", details: forceResult.message)
                                    self.logService.addLog(
                                        hostId: processId,
                                        message: "⚠️ Force killed: \(forceResult.message)",
                                        isError: false
                                    )
                                    
                                    // ✅ Stop the process in ProcessService to prevent auto-restart
                                    self.processService.stopHost(processId)
                                    self.hostStates[processId] = .stopped
                                    self.updateHostAggregateState(host)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func checkPortStatus(_ port: Int) -> String? {
        if let processInfo = portKillerService.findProcessOnPort(port) {
            return "\(processInfo.processName) (PID: \(processInfo.pid))"
        }
        return nil
    }
    
    // MARK: - Authentication
    
    func login() {
        isAuthenticating = true
        authStatus = "Logging in..."
        
        let command = settingsService.getLoginCommand()
        appLogService.info("Starting login process", details: "Command: \(command)")
        
        Task {
            do {
                // Login может открыть браузер для OAuth, не ждем завершения
                try await runAuthCommandAsync(command)
                
                await MainActor.run {
                    authStatus = "✅ Login process started (check browser)"
                    isAuthenticating = false
                    appLogService.success("Login command executed", details: "Browser authentication may be required")
                    
                    // Clear status after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.authStatus = ""
                    }
                }
            } catch {
                await MainActor.run {
                    authStatus = "❌ Login error: \(error.localizedDescription)"
                    isAuthenticating = false
                    appLogService.error("Login failed", details: error.localizedDescription)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.authStatus = ""
                    }
                }
            }
        }
    }
    
    func logout() {
        isAuthenticating = true
        authStatus = "Logging out..."
        
        let command = settingsService.getLogoutCommand()
        appLogService.info("Starting logout process", details: "Command: \(command)")
        
        Task {
            do {
                let result = try await runAuthCommand(command)
                await MainActor.run {
                    authStatus = result.success ? "✅ Logged out successfully" : "❌ Logout failed"
                    isAuthenticating = false
                    
                    if result.success {
                        appLogService.success("Logout successful")
                    } else {
                        appLogService.warning("Logout command completed with errors", details: result.output)
                    }
                    
                    // Clear status after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.authStatus = ""
                    }
                }
            } catch {
                await MainActor.run {
                    authStatus = "❌ Logout error: \(error.localizedDescription)"
                    isAuthenticating = false
                    appLogService.error("Logout failed", details: error.localizedDescription)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.authStatus = ""
                    }
                }
            }
        }
    }
    
    // Async version for login (doesn't wait for completion, allows browser redirect)
    private func runAuthCommandAsync(_ command: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                
                // Parse command
                let parts = command.split(separator: " ").map(String.init)
                guard let executable = parts.first else {
                    continuation.resume(throwing: NSError(
                        domain: "AppViewModel",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid command"]
                    ))
                    return
                }
                
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = Array(parts.dropFirst())
                
                // Set environment
                var environment = Foundation.ProcessInfo.processInfo.environment
                if let shellPath = self.getShellPATH() {
                    environment["PATH"] = shellPath
                }
                process.environment = environment
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    // Don't wait for completion - login may open browser
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func runAuthCommand(_ command: String) async throws -> (success: Bool, output: String) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                
                // Parse command
                let parts = command.split(separator: " ").map(String.init)
                guard let executable = parts.first else {
                    continuation.resume(returning: (false, "Invalid command"))
                    return
                }
                
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = Array(parts.dropFirst())
                
                // Set environment
                var environment = Foundation.ProcessInfo.processInfo.environment
                if let shellPath = self.getShellPATH() {
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
                    
                    let exitCode = process.terminationStatus
                    let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let error = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    
                    let fullOutput = output + (error.isEmpty ? "" : "\n\(error)")
                    continuation.resume(returning: (exitCode == 0, fullOutput))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func getShellPATH() -> String? {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        
        let configFiles = [
            "\(homeDir)/.zshrc",
            "\(homeDir)/.zprofile",
            "\(homeDir)/.bash_profile",
            "\(homeDir)/.bashrc"
        ]
        
        var pathComponents: Set<String> = [
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin"
        ]
        
        for configFile in configFiles {
            if let content = try? String(contentsOfFile: configFile, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("export PATH=") || line.hasPrefix("PATH=") {
                        if let range = line.range(of: "=") {
                            let pathValue = String(line[range.upperBound...])
                                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
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
        
        if let systemPath = Foundation.ProcessInfo.processInfo.environment["PATH"] {
            pathComponents.formUnion(systemPath.components(separatedBy: ":"))
        }
        
        let validPaths = pathComponents.filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        
        return validPaths.joined(separator: ":")
    }
}

