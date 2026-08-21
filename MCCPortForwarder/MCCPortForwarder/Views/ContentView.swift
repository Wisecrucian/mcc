//
//  ContentView.swift
//  MCCPortForwarder
//

import SwiftUI

struct ContentView: View {
    
    @StateObject private var viewModel = AppViewModel()
    @State private var expandedServices: Set<UUID> = []
    
    // Modal states
    @State private var showingAddService = false
    @State private var addServiceParentId: UUID?
    @State private var showingAddHost: UUID?
    @State private var showingEditService: Service?
    @State private var showingEditHost: EditHostData?
    
    // Form data
    @State private var serviceName = ""
    @State private var hostName = ""
    @State private var hostHostname = ""
    @State private var hostTag = ""
    @State private var hostPorts: [PortMapping] = []
    @State private var newFromPort = ""
    @State private var newToPort = ""
    
    // New datacenter-based form data
    @State private var hostTemplate = ""
    @State private var hostRemotePort = ""
    @State private var selectedDatacenters: Set<String> = []
    @State private var datacenterPorts: [String: String] = [:] // datacenter -> base localPort
    @State private var datacenterInstanceNumbers: [String: [Int]] = [:] // datacenter -> real instance numbers (may be sparse)
    @State private var datacenterSourceNames: [String: [Int: String]] = [:] // datacenter -> instance number -> raw pasted name
    @State private var startingPort = "9999"
    @State private var pasteInstancesText = ""
    @State private var pasteParseMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Services list
            if viewModel.services.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(viewModel.services) { service in
                            renderService(service, level: 0)
                            
                            if service.id != viewModel.services.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.trailing, 8) // Отступ справа для скроллбара
                }
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingAddService) {
            addServiceSheet
        }
        .sheet(item: $showingAddHost) { serviceId in
            addHostSheet(serviceId: serviceId)
        }
        .sheet(item: $showingEditService) { service in
            editServiceSheet(service: service)
        }
        .sheet(item: $showingEditHost) { data in
            editHostSheet(editData: data)
        }
        .sheet(isPresented: $viewModel.showingLogViewer) {
            if let processId = viewModel.selectedHostForLogs {
                let displayName = viewModel.selectedLogName ?? findHost(processId)?.name ?? "Unknown"
                LogViewerView(
                    hostId: processId,
                    hostName: displayName,
                    logService: viewModel.logService
                )
            }
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showingAppLogs) {
            AppLogViewerView(appLogService: viewModel.appLogService)
        }
    }
    
    // MARK: - Recursive Service Rendering
    
    private func renderService(_ service: Service, level: Int) -> some View {
        ServiceRowView(
            service: service,
            state: viewModel.getServiceState(service),
            level: level,
            isExpanded: .init(
                get: { expandedServices.contains(service.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedServices.insert(service.id)
                    } else {
                        expandedServices.remove(service.id)
                    }
                }
            ),
            onStart: {
                viewModel.startService(service)
            },
            onStop: {
                viewModel.stopService(service)
            },
            onEdit: {
                showingEditService = service
            },
            onAddHost: {
                showingAddHost = service.id
            },
            onAddChildService: {
                addServiceParentId = service.id
                showingAddService = true
            },
            onEditHost: { host in
                showingEditHost = EditHostData(host: host, serviceId: service.id)
            },
            onDeleteHost: { hostId in
                viewModel.deleteHost(hostId, from: service.id)
            },
            onToggleHost: { host in
                viewModel.toggleHost(host)
            },
            onShowLogs: { hostId in
                viewModel.showLogs(for: hostId)
            },
            onKillPort: { host, portMapping in
                viewModel.killProcessOnPort(portMapping.toPort, forHost: host, portMapping: portMapping)
            },
            onDelete: {
                viewModel.deleteService(service)
            },
            getHostState: viewModel.getHostState,
            getPortState: { host, port in
                viewModel.getPortState(host: host, port: port)
            },
            onTogglePort: { host, port in
                viewModel.togglePort(host: host, port: port)
            },
            onShowLogsForPort: { processId, name in
                viewModel.showLogs(for: processId, name: name)
            },
            getLocationVersion: { location in viewModel.locationVersions[location.id] },
            getLocationVersionError: { location in viewModel.locationVersionErrors[location.id] },
            onRefreshVersion: { location in viewModel.refreshVersion(for: location) },
            renderChildService: { childService, childLevel in
                AnyView(renderService(childService, level: childLevel))
            }
        )
    }
    
    // MARK: - Helper Methods
    
    private func findHost(_ hostId: UUID) -> Host? {
        findHostRecursive(hostId, in: viewModel.services)
    }
    
    private func findHostRecursive(_ hostId: UUID, in services: [Service]) -> Host? {
        for service in services {
            if let host = service.hosts.first(where: { $0.id == hostId }) {
                return host
            }
            if let host = findHostRecursive(hostId, in: service.childServices) {
                return host
            }
        }
        return nil
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("MCC Port Forwarder")
                .font(.system(size: 14, weight: .semibold))
            
            Spacer()
            
            Button(action: { 
                viewModel.showingSettings = true
            }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
            
            Button(action: { 
                addServiceParentId = nil
                showingAddService = true 
            }) {
                Image(systemName: "plus.circle")
            }
            .buttonStyle(.plain)
            .help("Add root service")
            
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Services")
                .font(.system(size: 16, weight: .medium))
            
            Text("Add a service to get started")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            Button("Add Service") {
                addServiceParentId = nil
                showingAddService = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        VStack(spacing: 8) {
            // Auth status
            if !viewModel.authStatus.isEmpty {
                Text(viewModel.authStatus)
                    .font(.system(size: 11))
                    .foregroundColor(viewModel.authStatus.hasPrefix("✅") ? .green : .red)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            
            HStack {
                // Auth buttons
                Button(action: { viewModel.logout() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.square")
                        Text("Logout")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isAuthenticating)
                
                Button(action: { viewModel.login() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.key")
                        Text("Login")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isAuthenticating)
                
                Spacer()
                
                Text("\(activeConnectionsCount) active connection\(activeConnectionsCount == 1 ? "" : "s")")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private var activeConnectionsCount: Int {
        // Count only port processes, not host aggregate states
        var count = 0
        for service in viewModel.services {
            count += countRunningPorts(in: service)
        }
        return count
    }
    
    private func countRunningPorts(in service: Service) -> Int {
        var count = 0
        // Count running ports in hosts
        for host in service.hosts {
            for port in host.compatiblePorts {
                let processId = host.processId(for: port)
                let state = viewModel.hostStates[processId] ?? .stopped
                // Count only ready connections
                if state == .ready {
                    count += 1
                }
            }
        }
        // Count running ports in child services
        for child in service.childServices {
            count += countRunningPorts(in: child)
        }
        return count
    }
    
    // MARK: - Add Service Sheet
    
    private var addServiceSheet: some View {
        VStack(spacing: 16) {
            Text(addServiceParentId == nil ? "Add Service" : "Add Sub-Service")
                .font(.headline)
            
            TextField("Service Name", text: $serviceName)
                .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Cancel") {
                    showingAddService = false
                    serviceName = ""
                    addServiceParentId = nil
                }
                
                Button("Add") {
                    if !serviceName.isEmpty {
                        viewModel.addService(name: serviceName, parentId: addServiceParentId)
                        showingAddService = false
                        serviceName = ""
                        addServiceParentId = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(serviceName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Edit Service Sheet
    
    private func editServiceSheet(service: Service) -> some View {
        VStack(spacing: 16) {
            Text("Edit Service")
                .font(.headline)
            
            TextField("Service Name", text: $serviceName)
                .textFieldStyle(.roundedBorder)
                .onAppear {
                    serviceName = service.name
                }
            
            HStack {
                Button("Cancel") {
                    showingEditService = nil
                    serviceName = ""
                }
                
                Button("Save") {
                    if !serviceName.isEmpty {
                        var updated = service
                        updated.name = serviceName
                        viewModel.updateService(updated)
                        showingEditService = nil
                        serviceName = ""
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(serviceName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Add Host Sheet
    
    private func addHostSheet(serviceId: UUID) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Add Host")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Name")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("e.g., postgres-master", text: $hostName)
                        .textFieldStyle(.roundedBorder)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hostname Template")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("e.g., href.dfsdf.{location}.ru", text: $hostTemplate)
                        .textFieldStyle(.roundedBorder)
                    Text("Use {location} for datacenter, {instance} for the instance number")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Remote Port (on server)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("e.g., 5432", text: Binding(
                        get: { hostRemotePort },
                        set: { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            hostRemotePort = filtered
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .disableAutocorrection(true)
                    .font(.system(size: 12, design: .monospaced))
                }

                Divider()

                datacenterSelectionSection

                HStack {
                    Button("Cancel") {
                        showingAddHost = nil
                        resetHostForm()
                    }

                    Button("Add Host") {
                        addNewHostWithDatacenters(to: serviceId)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hostName.isEmpty || hostTemplate.isEmpty || hostRemotePort.isEmpty || selectedDatacenters.isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 450, height: 600)
    }

    // MARK: - Datacenter Selection Section (shared by Add/Edit Host sheets)

    @ViewBuilder
    private var datacenterSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !viewModel.settingsService.datacenters.isEmpty {
                pasteInstancesSection
                Divider()
            }

            HStack {
                Text("Select Datacenters")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(selectedDatacenters.count) selected")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            if viewModel.settingsService.datacenters.isEmpty {
                Text("No datacenters configured. Add them in Settings first.")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .padding(8)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.settingsService.datacenters, id: \.self) { dc in
                        datacenterRow(dc)
                    }
                }

                HStack {
                    Text("Starting port:")
                        .font(.system(size: 10))
                    TextField("9999", text: Binding(
                        get: { startingPort },
                        set: { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            startingPort = filtered
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .disableAutocorrection(true)
                    .font(.system(size: 12, design: .monospaced))
                    Button("Auto-assign") {
                        reassignDatacenterPorts()
                    }
                    .font(.system(size: 10))
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var pasteInstancesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Paste instances (one per line, e.g. \"2.myservice.dc1\")")
                .font(.system(size: 11, weight: .medium))

            TextEditor(text: $pasteInstancesText)
                .font(.system(size: 11, design: .monospaced))
                .frame(height: 54)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )

            HStack {
                Button("Parse & Fill In") {
                    parsePastedInstances()
                }
                .font(.system(size: 11))
                .disabled(pasteInstancesText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                if !pasteParseMessage.isEmpty {
                    Text(pasteParseMessage)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func parsePastedInstances() {
        let parsed = InstanceNameParser.parseLines(pasteInstancesText, knownDatacenters: viewModel.settingsService.datacenters)

        guard !parsed.isEmpty else {
            pasteParseMessage = "No matching instances found — check the datacenter list in Settings."
            return
        }

        for item in parsed {
            selectedDatacenters.insert(item.datacenter)

            var numbers = Set(datacenterInstanceNumbers[item.datacenter] ?? [])
            // Drop the placeholder "instance 1" that a bare checkbox-toggle would have set,
            // once we have a real parsed instance to replace it with.
            if numbers == [1], datacenterSourceNames[item.datacenter]?[1] == nil {
                numbers = []
            }
            numbers.insert(item.instanceNumber)
            datacenterInstanceNumbers[item.datacenter] = numbers.sorted()
            datacenterSourceNames[item.datacenter, default: [:]][item.instanceNumber] = item.raw

            if datacenterPorts[item.datacenter] == nil {
                datacenterPorts[item.datacenter] = "\(nextAvailableBasePort())"
            }
        }

        let datacenterCount = Set(parsed.map(\.datacenter)).count
        pasteParseMessage = "Parsed \(parsed.count) instance(s) across \(datacenterCount) datacenter(s)."
        pasteInstancesText = ""
    }

    @ViewBuilder
    private func datacenterRow(_ dc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Toggle(isOn: Binding(
                    get: { selectedDatacenters.contains(dc) },
                    set: { isSelected in
                        if isSelected {
                            let basePort = nextAvailableBasePort()
                            selectedDatacenters.insert(dc)
                            if datacenterInstanceNumbers[dc] == nil {
                                datacenterInstanceNumbers[dc] = [1]
                            }
                            if datacenterPorts[dc] == nil {
                                datacenterPorts[dc] = "\(basePort)"
                            }
                        } else {
                            selectedDatacenters.remove(dc)
                            datacenterPorts.removeValue(forKey: dc)
                            datacenterInstanceNumbers.removeValue(forKey: dc)
                            datacenterSourceNames.removeValue(forKey: dc)
                        }
                    }
                )) {
                    Text(dc)
                        .font(.system(size: 12, design: .monospaced))
                }
                .toggleStyle(.checkbox)

                Spacer()

                if selectedDatacenters.contains(dc) {
                    Text("→")
                        .foregroundColor(.secondary)
                    TextField("Port", text: Binding(
                        get: { datacenterPorts[dc] ?? "" },
                        set: { newValue in
                            // Filter only digits
                            let filtered = newValue.filter { $0.isNumber }
                            datacenterPorts[dc] = filtered
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 70)
                    .multilineTextAlignment(.center)
                    .disableAutocorrection(true)
                    .font(.system(size: 12, design: .monospaced))

                    Stepper(
                        "×\(datacenterInstanceNumbers[dc]?.count ?? 1)",
                        onIncrement: {
                            var numbers = datacenterInstanceNumbers[dc] ?? [1]
                            numbers.append((numbers.max() ?? 0) + 1)
                            datacenterInstanceNumbers[dc] = numbers
                        },
                        onDecrement: {
                            var numbers = datacenterInstanceNumbers[dc] ?? [1]
                            guard numbers.count > 1 else { return }
                            let removed = numbers.removeLast()
                            datacenterSourceNames[dc]?.removeValue(forKey: removed)
                            datacenterInstanceNumbers[dc] = numbers
                        }
                    )
                    .font(.system(size: 11))
                    .fixedSize()
                }
            }

            if selectedDatacenters.contains(dc),
               let numbers = datacenterInstanceNumbers[dc], numbers.count > 1,
               let basePort = Int(datacenterPorts[dc] ?? "") {
                let sorted = numbers.sorted()
                Text("Instances → " + sorted.enumerated().map { offset, num in "#\(num)=\(basePort + offset)" }.joined(separator: ", "))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.leading, 20)
            }
        }
    }

    // Next free base port, packed after all currently-selected datacenters' instances
    private func nextAvailableBasePort() -> Int {
        let base = Int(startingPort) ?? 9999
        let used = selectedDatacenters.reduce(0) { $0 + (datacenterInstanceNumbers[$1]?.count ?? 1) }
        return base + used
    }

    // Repacks every selected datacenter's ports sequentially, back to back with its instance count
    private func reassignDatacenterPorts() {
        let base = Int(startingPort) ?? 9999
        var cursor = base
        for dc in selectedDatacenters.sorted() {
            datacenterPorts[dc] = "\(cursor)"
            cursor += datacenterInstanceNumbers[dc]?.count ?? 1
        }
    }
    
    private func addNewHostWithDatacenters(to serviceId: UUID) {
        guard !hostName.isEmpty,
              !hostTemplate.isEmpty,
              let remotePort = Int(hostRemotePort),
              !selectedDatacenters.isEmpty else { return }
        
        // Create locations from selected datacenters, expanding each into its instance numbers
        var locations: [LocationMapping] = []
        for dc in selectedDatacenters.sorted() {
            if let portStr = datacenterPorts[dc], let basePort = Int(portStr) {
                let numbers = (datacenterInstanceNumbers[dc] ?? [1]).sorted()
                for (offset, num) in numbers.enumerated() {
                    let sourceName = datacenterSourceNames[dc]?[num]
                    locations.append(LocationMapping(datacenter: dc, instance: num, localPort: basePort + offset, sourceInstanceName: sourceName))
                }
            }
        }

        guard !locations.isEmpty else { return }

        // Add host with new structure
        viewModel.addHostWithLocations(
            to: serviceId,
            name: hostName,
            hostnameTemplate: hostTemplate,
            remotePort: remotePort,
            locations: locations
        )
        
        showingAddHost = nil
        resetHostForm()
    }
    
    private func resetHostForm() {
        hostName = ""
        hostHostname = ""
        hostTag = ""
        hostPorts = []
        newFromPort = ""
        newToPort = ""
        // New form fields
        hostTemplate = ""
        hostRemotePort = ""
        selectedDatacenters = []
        datacenterPorts = [:]
        datacenterInstanceNumbers = [:]
        datacenterSourceNames = [:]
        startingPort = "9999"
        pasteInstancesText = ""
        pasteParseMessage = ""
    }
    
    // MARK: - Edit Host Sheet
    
    private func editHostSheet(editData: EditHostData) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Edit Host")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Name")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("e.g., postgres-master", text: $hostName)
                        .textFieldStyle(.roundedBorder)
                }
                .onAppear {
                    loadHostDataForEdit(editData.host)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hostname Template")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("e.g., href.dfsdf.{location}.ru", text: $hostTemplate)
                        .textFieldStyle(.roundedBorder)
                    Text("Use {location} for datacenter, {instance} for the instance number")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Remote Port (on server)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    TextField("e.g., 5432", text: Binding(
                        get: { hostRemotePort },
                        set: { newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            hostRemotePort = filtered
                        }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .disableAutocorrection(true)
                    .font(.system(size: 12, design: .monospaced))
                }

                Divider()

                datacenterSelectionSection

                HStack {
                    Button("Cancel") {
                        showingEditHost = nil
                        resetHostForm()
                    }

                    Button("Save Changes") {
                        saveEditedHost(editData: editData)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(hostName.isEmpty || hostTemplate.isEmpty || hostRemotePort.isEmpty || selectedDatacenters.isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 450, height: 600)
    }
    
    private func loadHostDataForEdit(_ host: Host) {
        hostName = host.name
        hostTemplate = host.hostnameTemplate
        hostRemotePort = "\(host.remotePort)"
        
        // Load locations, grouped by datacenter (each group may span several instances)
        selectedDatacenters = Set(host.locations.map { $0.datacenter })

        var ports: [String: String] = [:]
        var numbers: [String: [Int]] = [:]
        var sourceNames: [String: [Int: String]] = [:]
        for dc in selectedDatacenters {
            let group = host.locations.filter { $0.datacenter == dc }.sorted { $0.instance < $1.instance }
            numbers[dc] = group.map(\.instance)
            for location in group {
                if let name = location.sourceInstanceName {
                    sourceNames[dc, default: [:]][location.instance] = name
                }
            }
            ports[dc] = "\(group.first?.localPort ?? 9999)"
        }
        datacenterPorts = ports
        datacenterInstanceNumbers = numbers
        datacenterSourceNames = sourceNames

        // Set starting port to the lowest assigned port, or default
        if let minPort = host.locations.map({ $0.localPort }).min() {
            startingPort = "\(minPort)"
        } else {
            startingPort = "9999"
        }
    }
    
    private func saveEditedHost(editData: EditHostData) {
        guard !hostName.isEmpty,
              !hostTemplate.isEmpty,
              let remotePort = Int(hostRemotePort),
              !selectedDatacenters.isEmpty else { return }
        
        // Create locations from selected datacenters, expanding each into its instance numbers
        var locations: [LocationMapping] = []
        for dc in selectedDatacenters.sorted() {
            if let portStr = datacenterPorts[dc], let basePort = Int(portStr) {
                let numbers = (datacenterInstanceNumbers[dc] ?? [1]).sorted()
                for (offset, num) in numbers.enumerated() {
                    let sourceName = datacenterSourceNames[dc]?[num]
                    locations.append(LocationMapping(datacenter: dc, instance: num, localPort: basePort + offset, sourceInstanceName: sourceName))
                }
            }
        }

        guard !locations.isEmpty else { return }

        // Update host
        viewModel.updateHostWithLocations(
            hostId: editData.host.id,
            in: editData.serviceId,
            name: hostName,
            hostnameTemplate: hostTemplate,
            remotePort: remotePort,
            locations: locations
        )
        
        showingEditHost = nil
        resetHostForm()
    }
}

// MARK: - Helper Types

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}

struct EditHostData: Identifiable {
    let host: Host
    let serviceId: UUID
    var id: UUID { host.id }
}
