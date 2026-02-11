package com.mcc.portforwarder.services

import com.intellij.execution.configurations.GeneralCommandLine
import com.intellij.execution.process.OSProcessHandler
import com.intellij.execution.process.ProcessAdapter
import com.intellij.execution.process.ProcessEvent
import com.intellij.openapi.Disposable
import com.intellij.openapi.components.Service
import com.intellij.openapi.components.service
import com.intellij.openapi.project.Project
import com.intellij.openapi.util.Key
import com.mcc.portforwarder.models.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.*
import java.util.concurrent.ConcurrentHashMap

/**
 * Main service managing port forwarding (правильный Project-level service)
 */
@Service(Service.Level.PROJECT)
class MCCService(private val project: Project) : Disposable {
    
    // State
    private val _services = MutableStateFlow<List<MCCServiceModel>>(emptyList())
    val services: StateFlow<List<MCCServiceModel>> = _services
    
    private val _processStates = MutableStateFlow<Map<UUID, ProcessState>>(emptyMap())
    val processStates: StateFlow<Map<UUID, ProcessState>> = _processStates
    
    private val _processLogs = MutableStateFlow<Map<UUID, List<String>>>(emptyMap())
    val processLogs: StateFlow<Map<UUID, List<String>>> = _processLogs
    
    private val _appLogs = MutableStateFlow<List<String>>(emptyList())
    val appLogs: StateFlow<List<String>> = _appLogs
    
    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated
    
    // Active processes
    private val activeProcesses = ConcurrentHashMap<UUID, OSProcessHandler>()
    
    init {
        // Load saved services
        loadServices()
    }
    
    // ==================== Service Management ====================
    
    fun addService(service: MCCServiceModel) {
        val current = _services.value.toMutableList()
        current.add(service)
        _services.value = current.toList() // Create new list to trigger StateFlow update
        saveServices()
        logApp("✅ Service added: ${service.name}")
    }
    
    fun updateService(updated: MCCServiceModel) {
        val current = _services.value.toMutableList()
        val index = current.indexOfFirst { it.id == updated.id }
        if (index >= 0) {
            current[index] = updated
            _services.value = current.toList() // Create new list to trigger StateFlow update
            saveServices()
            logApp("✏️ Service updated: ${updated.name}")
        }
    }
    
    fun deleteService(serviceId: UUID) {
        val service = findService(serviceId)
        if (service != null) {
            // Stop all hosts first
            service.allHosts.forEach { host ->
                stopHost(host)
            }
            
            val current = _services.value.toMutableList()
            removeServiceRecursively(current, serviceId)
            _services.value = current.toList() // Create new list to trigger StateFlow update
            saveServices()
            logApp("🗑️ Service deleted: ${service.name}")
        }
    }
    
    private fun removeServiceRecursively(services: MutableList<MCCServiceModel>, serviceId: UUID): Boolean {
        val iterator = services.iterator()
        while (iterator.hasNext()) {
            val service = iterator.next()
            if (service.id == serviceId) {
                iterator.remove()
                return true
            }
            if (removeServiceRecursively(service.childServices, serviceId)) {
                return true
            }
        }
        return false
    }
    
    // ==================== Host Management ====================
    
    fun addHostToService(serviceId: UUID, host: Host) {
        val service = findService(serviceId)
        if (service != null) {
            service.hosts.add(host)
            saveServices()
            logApp("✅ Host added: ${host.name} to ${service.name}")
            
            // Force StateFlow update by reassigning
            val temp = _services.value
            _services.value = emptyList()  // Trigger change
            _services.value = temp  // Restore with modification
        }
    }
    
    fun updateHost(host: Host) {
        saveServices()
        logApp("✏️ Host updated: ${host.name}")
        
        // Force StateFlow update
        val temp = _services.value
        _services.value = emptyList()
        _services.value = temp
    }
    
    fun deleteHost(hostId: UUID) {
        val host = findHost(hostId)
        if (host != null) {
            stopHost(host)
            
            val current = _services.value.toMutableList()
            removeHostRecursively(current, hostId)
            _services.value = current.toList() // Create new list to trigger StateFlow update
            saveServices()
            logApp("🗑️ Host deleted: ${host.name}")
        }
    }
    
    private fun removeHostRecursively(services: MutableList<MCCServiceModel>, hostId: UUID): Boolean {
        for (service in services) {
            val removed = service.hosts.removeIf { it.id == hostId }
            if (removed) return true
            if (removeHostRecursively(service.childServices, hostId)) return true
        }
        return false
    }
    
    // ==================== Process Management ====================
    
    fun startService(serviceId: UUID) {
        val service = findService(serviceId)
        if (service != null) {
            logApp("▶️ Starting service: ${service.name}")
            service.allHosts.forEach { host ->
                startHost(host)
            }
        }
    }
    
    fun stopService(serviceId: UUID) {
        val service = findService(serviceId)
        if (service != null) {
            logApp("⏹️ Stopping service: ${service.name}")
            service.allHosts.forEach { host ->
                stopHost(host)
            }
        }
    }
    
    fun startHost(host: Host) {
        logApp("▶️ Starting host: ${host.name}")
        host.locations.forEach { location ->
            startLocation(host, location)
        }
    }
    
    fun stopHost(host: Host) {
        logApp("⏹️ Stopping host: ${host.name}")
        host.locations.forEach { location ->
            stopLocation(host, location)
        }
    }
    
    fun toggleLocation(host: Host, location: LocationMapping) {
        val processId = host.processId(location)
        val state = _processStates.value[processId] ?: ProcessState.STOPPED
        
        if (state.isActive) {
            stopLocation(host, location)
        } else {
            startLocation(host, location)
        }
    }
    
    private fun startLocation(host: Host, location: LocationMapping) {
        val processId = host.processId(location)
        val hostname = host.resolvedHostname(location)
        val settings = MCCSettings.getInstance()
        
        // Check if already running
        if (activeProcesses.containsKey(processId)) {
            logProcess(processId, "⚠️ Already running")
            return
        }
        
        updateProcessState(processId, ProcessState.RESTARTING)
        logProcess(processId, "🔄 Connecting to $hostname:${host.remotePort} -> localhost:${location.localPort}")
        
        try {
            val commandLine = GeneralCommandLine(
                settings.forwardCommand,
                "--host", hostname,
                "--from", location.localPort.toString(),
                "--to", host.remotePort.toString()
            )
            
            val handler = OSProcessHandler(commandLine)
            handler.addProcessListener(object : ProcessAdapter() {
                override fun onTextAvailable(event: ProcessEvent, outputType: Key<*>) {
                    val text = event.text.trim()
                    if (text.isNotEmpty()) {
                        logProcess(processId, text)
                        analyzeLogLine(processId, text)
                    }
                }
                
                override fun processTerminated(event: ProcessEvent) {
                    logProcess(processId, "❌ Process terminated with code ${event.exitCode}")
                    updateProcessState(processId, ProcessState.ERROR)
                    activeProcesses.remove(processId)
                    
                    // Auto-retry if enabled
                    if (settings.retryEnabled && event.exitCode != 0) {
                        // TODO: Implement retry logic
                    }
                }
            })
            
            handler.startNotify()
            activeProcesses[processId] = handler
            
        } catch (e: Exception) {
            logProcess(processId, "❌ Failed to start: ${e.message}")
            updateProcessState(processId, ProcessState.ERROR)
        }
    }
    
    private fun stopLocation(host: Host, location: LocationMapping) {
        val processId = host.processId(location)
        val handler = activeProcesses.remove(processId)
        
        if (handler != null && !handler.isProcessTerminated) {
            handler.destroyProcess()
            logProcess(processId, "⏹️ Stopped")
        }
        
        updateProcessState(processId, ProcessState.STOPPED)
    }
    
    private fun analyzeLogLine(processId: UUID, line: String) {
        when {
            line.contains("Proxying connections", ignoreCase = true) -> {
                updateProcessState(processId, ProcessState.RUNNING)
            }
            line.contains("port is already allocated", ignoreCase = true) ||
            line.contains("address already in use", ignoreCase = true) -> {
                updateProcessState(processId, ProcessState.PORT_IN_USE)
            }
            line.contains("error", ignoreCase = true) ||
            line.contains("failed", ignoreCase = true) -> {
                updateProcessState(processId, ProcessState.ERROR)
            }
        }
    }
    
    // ==================== Authentication ====================
    
    fun login() {
        logApp("🔐 Logging in...")
        val settings = MCCSettings.getInstance()
        
        // Show notification
        com.intellij.notification.Notifications.Bus.notify(
            com.intellij.notification.Notification(
                "MCC",
                "Login",
                "Executing: ${settings.loginCommand}",
                com.intellij.notification.NotificationType.INFORMATION
            )
        )
        
        executeCommand(settings.loginCommand) { success, output ->
            if (success) {
                _isAuthenticated.value = true
                logApp("✅ Login successful")
                com.intellij.notification.Notifications.Bus.notify(
                    com.intellij.notification.Notification(
                        "MCC",
                        "Login Successful",
                        "You are now authenticated",
                        com.intellij.notification.NotificationType.INFORMATION
                    )
                )
            } else {
                _isAuthenticated.value = false
                logApp("❌ Login failed: $output")
                com.intellij.notification.Notifications.Bus.notify(
                    com.intellij.notification.Notification(
                        "MCC",
                        "Login Failed",
                        "Error: $output",
                        com.intellij.notification.NotificationType.ERROR
                    )
                )
            }
        }
    }
    
    fun logout() {
        logApp("🔓 Logging out...")
        
        // Show notification
        com.intellij.notification.Notifications.Bus.notify(
            com.intellij.notification.Notification(
                "MCC",
                "Logout",
                "Stopping all processes and logging out...",
                com.intellij.notification.NotificationType.INFORMATION
            )
        )
        
        // Stop all processes
        _services.value.forEach { service ->
            stopService(service.id)
        }
        
        val settings = MCCSettings.getInstance()
        executeCommand(settings.logoutCommand) { success, output ->
            _isAuthenticated.value = false
            if (success) {
                logApp("✅ Logout successful")
                com.intellij.notification.Notifications.Bus.notify(
                    com.intellij.notification.Notification(
                        "MCC",
                        "Logout Successful",
                        "You have been logged out",
                        com.intellij.notification.NotificationType.INFORMATION
                    )
                )
            } else {
                logApp("❌ Logout failed: $output")
                com.intellij.notification.Notifications.Bus.notify(
                    com.intellij.notification.Notification(
                        "MCC",
                        "Logout Failed",
                        "Error: $output",
                        com.intellij.notification.NotificationType.WARNING
                    )
                )
            }
        }
    }
    
    private fun executeCommand(command: String, callback: (Boolean, String) -> Unit) {
        try {
            val commandLine = GeneralCommandLine("/bin/sh", "-c", command)
            val handler = OSProcessHandler(commandLine)
            val output = StringBuilder()
            
            handler.addProcessListener(object : ProcessAdapter() {
                override fun onTextAvailable(event: ProcessEvent, outputType: Key<*>) {
                    output.append(event.text)
                }
                
                override fun processTerminated(event: ProcessEvent) {
                    callback(event.exitCode == 0, output.toString())
                }
            })
            
            handler.startNotify()
        } catch (e: Exception) {
            callback(false, e.message ?: "Unknown error")
        }
    }
    
    // ==================== State Management ====================
    
    private fun updateProcessState(processId: UUID, state: ProcessState) {
        val current = _processStates.value.toMutableMap()
        current[processId] = state
        _processStates.value = current
    }
    
    fun getProcessState(processId: UUID): ProcessState {
        return _processStates.value[processId] ?: ProcessState.STOPPED
    }
    
    private fun logProcess(processId: UUID, message: String) {
        val current = _processLogs.value.toMutableMap()
        val logs = current.getOrDefault(processId, emptyList()).toMutableList()
        logs.add("[${java.time.LocalTime.now()}] $message")
        current[processId] = logs
        _processLogs.value = current
    }
    
    fun getProcessLogs(processId: UUID): List<String> {
        return _processLogs.value[processId] ?: emptyList()
    }
    
    fun clearProcessLogs(processId: UUID) {
        val current = _processLogs.value.toMutableMap()
        current[processId] = emptyList()
        _processLogs.value = current
    }
    
    fun logApp(message: String, isError: Boolean = false) {
        val current = _appLogs.value.toMutableList()
        current.add("[${java.time.LocalTime.now()}] $message")
        _appLogs.value = current
    }
    
    fun clearAppLogs() {
        _appLogs.value = emptyList()
    }
    
    // ==================== Import/Export ====================
    
    fun exportConfiguration(): ConfigurationExport {
        val settings = MCCSettings.getInstance()
        return ConfigurationExport(
            version = "1.0",
            datacenters = settings.getDatacenters(),
            services = _services.value.map { it.toExport() }
        )
    }
    
    fun importConfiguration(config: ConfigurationExport) {
        // Replace datacenters
        val settings = MCCSettings.getInstance()
        if (config.datacenters != null) {
            settings.replaceDatacenters(config.datacenters)
            logApp("📥 Imported ${config.datacenters.size} datacenters")
        } else {
            logApp("⚠️ No datacenters in configuration, keeping existing")
        }
        
        // Import services
        if (config.services != null) {
            val imported = config.services.map { it.toService() }
            _services.value = imported
            saveServices()
            logApp("📥 Configuration imported: ${imported.size} services")
        } else {
            logApp("⚠️ No services in configuration")
        }
    }
    
    private fun MCCServiceModel.toExport(): MCCServiceExport = MCCServiceExport(
        name = name,
        hosts = hosts.map { it.toExport() },
        childServices = childServices.map { it.toExport() }
    )
    
    private fun Host.toExport(): HostExport = HostExport(
        name = name,
        hostnameTemplate = hostnameTemplate,
        remotePort = remotePort,
        locations = locations.map { it.toExport() }
    )
    
    private fun LocationMapping.toExport(): LocationMappingExport = LocationMappingExport(
        datacenter = datacenter,
        localPort = localPort
    )
    
    private fun MCCServiceExport.toService(): MCCServiceModel = MCCServiceModel(
        name = name,
        hosts = (hosts ?: emptyList()).map { it.toHost() }.toMutableList(),
        childServices = (childServices ?: emptyList()).map { it.toService() }.toMutableList()
    )
    
    private fun HostExport.toHost(): Host = Host(
        name = name,
        hostnameTemplate = hostnameTemplate,
        remotePort = remotePort,
        locations = (locations ?: emptyList()).map { it.toLocation() }.toMutableList()
    )
    
    private fun LocationMappingExport.toLocation(): LocationMapping = LocationMapping(
        datacenter = datacenter,
        localPort = localPort
    )
    
    // ==================== Helpers ====================
    
    fun findService(serviceId: UUID): MCCServiceModel? {
        return findServiceRecursively(_services.value, serviceId)
    }
    
    private fun findServiceRecursively(services: List<MCCServiceModel>, serviceId: UUID): MCCServiceModel? {
        for (service in services) {
            if (service.id == serviceId) return service
            val found = findServiceRecursively(service.childServices, serviceId)
            if (found != null) return found
        }
        return null
    }
    
    fun findHost(hostId: UUID): Host? {
        return findHostRecursively(_services.value, hostId)
    }
    
    private fun findHostRecursively(services: List<MCCServiceModel>, hostId: UUID): Host? {
        for (service in services) {
            service.hosts.firstOrNull { it.id == hostId }?.let { return it }
            val found = findHostRecursively(service.childServices, hostId)
            if (found != null) return found
        }
        return null
    }
    
    fun getActiveConnectionCount(): Int {
        return _processStates.value.count { it.value.isActive }
    }
    
    // ==================== Persistence ====================
    
    private fun loadServices() {
        val storage = MCCStorage.getInstance()
        _services.value = storage.loadServices()
    }
    
    private fun saveServices() {
        val storage = MCCStorage.getInstance()
        storage.saveServices(_services.value)
    }
    
    // ==================== Disposal ====================
    
    override fun dispose() {
        // Stop all processes
        activeProcesses.values.forEach { handler ->
            if (!handler.isProcessTerminated) {
                handler.destroyProcess()
            }
        }
        activeProcesses.clear()
    }
    
    companion object {
        fun getInstance(project: Project): MCCService = project.service()
    }
}

