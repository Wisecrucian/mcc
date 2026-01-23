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
                Button(action: { viewModel.login() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.badge.key")
                        Text("Login")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.isAuthenticating)
                
                Button(action: { viewModel.logout() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.square")
                        Text("Logout")
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
        viewModel.hostStates.values.filter { $0 == .running }.count
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
        VStack(spacing: 16) {
            Text("Add Host")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("e.g., Production DB", text: $hostName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hostname")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("e.g., db.example.com", text: $hostHostname)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Tag (optional)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("e.g., DC1, EU-West, Production", text: $hostTag)
                    .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            // Ports section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Port Mappings")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(hostPorts.count) port(s)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                // Port list
                if !hostPorts.isEmpty {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(hostPorts) { port in
                                HStack {
                                    Text("\(port.fromPort) → \(port.toPort)")
                                        .font(.system(size: 11, design: .monospaced))
                                    Spacer()
                                    Button(action: {
                                        hostPorts.removeAll { $0.id == port.id }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
                
                // Add port form
                HStack(spacing: 8) {
                    TextField("From", text: $newFromPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("→")
                        .foregroundColor(.secondary)
                    TextField("To", text: $newToPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Button(action: {
                        if let from = Int(newFromPort), let to = Int(newToPort) {
                            hostPorts.append(PortMapping(fromPort: from, toPort: to))
                            newFromPort = ""
                            newToPort = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(Int(newFromPort) == nil || Int(newToPort) == nil)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            
            HStack {
                Button("Cancel") {
                    showingAddHost = nil
                    resetHostForm()
                }
                
                Button("Add") {
                    if !hostName.isEmpty && !hostHostname.isEmpty && !hostPorts.isEmpty {
                        let tag = hostTag.trimmingCharacters(in: .whitespaces)
                        viewModel.addHost(
                            to: serviceId,
                            name: hostName,
                            hostname: hostHostname,
                            tag: tag.isEmpty ? nil : tag,
                            ports: hostPorts
                        )
                        showingAddHost = nil
                        resetHostForm()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(hostName.isEmpty || hostHostname.isEmpty || hostPorts.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 550)
    }
    
    private func resetHostForm() {
        hostName = ""
        hostHostname = ""
        hostTag = ""
        hostPorts = []
        newFromPort = ""
        newToPort = ""
    }
    
    // MARK: - Edit Host Sheet
    
    private func editHostSheet(editData: EditHostData) -> some View {
        VStack(spacing: 16) {
            Text("Edit Host")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Display Name")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("e.g., Production DB", text: $hostName)
                    .textFieldStyle(.roundedBorder)
            }
            .onAppear {
                hostName = editData.host.name
                hostHostname = editData.host.hostname
                hostTag = editData.host.tag ?? ""
                hostPorts = editData.host.ports
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Hostname")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("e.g., db.example.com", text: $hostHostname)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Tag (optional)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                TextField("e.g., DC1, EU-West, Production", text: $hostTag)
                    .textFieldStyle(.roundedBorder)
            }
            
            Divider()
            
            // Ports section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Port Mappings")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(hostPorts.count) port(s)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                // Port list
                if !hostPorts.isEmpty {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(hostPorts) { port in
                                HStack {
                                    Text("\(port.fromPort) → \(port.toPort)")
                                        .font(.system(size: 11, design: .monospaced))
                                    Spacer()
                                    Button(action: {
                                        hostPorts.removeAll { $0.id == port.id }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                }
                
                // Add port form
                HStack(spacing: 8) {
                    TextField("From", text: $newFromPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("→")
                        .foregroundColor(.secondary)
                    TextField("To", text: $newToPort)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    
                    Button(action: {
                        if let from = Int(newFromPort), let to = Int(newToPort) {
                            hostPorts.append(PortMapping(fromPort: from, toPort: to))
                            newFromPort = ""
                            newToPort = ""
                        }
                    }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .disabled(Int(newFromPort) == nil || Int(newToPort) == nil)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.05))
            .cornerRadius(8)
            
            HStack {
                Button("Cancel") {
                    showingEditHost = nil
                    resetHostForm()
                }
                
                Button("Save") {
                    if !hostName.isEmpty && !hostHostname.isEmpty && !hostPorts.isEmpty {
                        var updated = editData.host
                        updated.name = hostName
                        updated.hostname = hostHostname
                        let tag = hostTag.trimmingCharacters(in: .whitespaces)
                        updated.tag = tag.isEmpty ? nil : tag
                        updated.ports = hostPorts
                        viewModel.updateHost(updated, in: editData.serviceId)
                        showingEditHost = nil
                        resetHostForm()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(hostName.isEmpty || hostHostname.isEmpty || hostPorts.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 550)
    }
}

// MARK: - Helper Types

extension UUID: Identifiable {
    public var id: UUID { self }
}

struct EditHostData: Identifiable {
    let host: Host
    let serviceId: UUID
    var id: UUID { host.id }
}
