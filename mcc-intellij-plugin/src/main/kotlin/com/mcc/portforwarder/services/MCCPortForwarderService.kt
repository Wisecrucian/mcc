package com.mcc.portforwarder.services

import com.intellij.openapi.components.Service
import com.intellij.openapi.components.service
import com.mcc.portforwarder.models.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

@Service(Service.Level.APP)
class MCCPortForwarderService {
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    private val _services = MutableStateFlow<List<com.mcc.portforwarder.models.Service>>(emptyList())
    val services: StateFlow<List<com.mcc.portforwarder.models.Service>> = _services
    
    private val _portStates = MutableStateFlow<Map<UUID, ProcessState>>(emptyMap())
    val portStates: StateFlow<Map<UUID, ProcessState>> = _portStates
    
    private val processes = ConcurrentHashMap<UUID, Process>()
    private val processStartTimes = ConcurrentHashMap<UUID, Long>()
    private val logs = ConcurrentHashMap<UUID, MutableList<String>>()
    
    private val settingsService = MCCSettingsService.getInstance()
    
    init {
        startStateMonitoring()
    }

    fun addService(service: com.mcc.portforwarder.models.Service) {
        println("🔍 [MCCService] addService() called for: ${service.name}")
        println("🔍 [MCCService] Current services count: ${_services.value.size}")
        _services.value = _services.value + service
        println("🔍 [MCCService] New services count: ${_services.value.size}")
        println("🔍 [MCCService] Service added: ${service.name}, id: ${service.id}, hosts: ${service.hosts.size}")
        saveToStorage()
    }

    fun updateService(service: com.mcc.portforwarder.models.Service) {
        _services.value = _services.value.map { if (it.id == service.id) service else it }
        saveToStorage()
    }

    fun deleteService(service: com.mcc.portforwarder.models.Service) {
        _services.value = _services.value.filter { it.id != service.id }
        saveToStorage()
    }

    fun startPort(host: Host, port: PortMapping) {
        val processId = host.processId(port)
        val settings = settingsService.getSettings()
        
        updateState(processId, ProcessState.CONNECTING)
        processStartTimes[processId] = System.currentTimeMillis()
        
        scope.launch {
            try {
                val hostname = if (host.usesNewStructure) {
                    val location = host.locations.find { it.localPort == port.toPort }
                    location?.let { host.resolvedHostname(it) } ?: host.compatibleHostname
                } else {
                    host.compatibleHostname
                }
                
                val command = "${settings.command} $hostname:${port.fromPort} -p ${port.toPort}"
                
                val processBuilder = ProcessBuilder(command.split(" "))
                processBuilder.redirectErrorStream(true)
                
                val process = processBuilder.start()
                processes[processId] = process
                
                // Read output
                scope.launch {
                    process.inputStream.bufferedReader().use { reader ->
                        reader.lines().forEach { line ->
                            addLog(processId, line)
                            ProcessState.fromLogMessage(line)?.let { newState ->
                                updateState(processId, newState)
                            }
                        }
                    }
                }
                
                // Wait for process
                val exitCode = process.waitFor()
                if (exitCode != 0) {
                    updateState(processId, ProcessState.ERROR)
                } else if (getState(processId) == ProcessState.READY) {
                    updateState(processId, ProcessState.DISCONNECTED)
                } else {
                    updateState(processId, ProcessState.STOPPED)
                }
                
            } catch (e: Exception) {
                addLog(processId, "Error: ${e.message}")
                updateState(processId, ProcessState.ERROR)
            } finally {
                processes.remove(processId)
                processStartTimes.remove(processId)
            }
        }
    }

    fun stopPort(host: Host, port: PortMapping) {
        val processId = host.processId(port)
        processes[processId]?.let { process ->
            scope.launch {
                try {
                    process.destroy()
                    delay(2000)
                    if (process.isAlive) {
                        process.destroyForcibly()
                    }
                } finally {
                    processes.remove(processId)
                    updateState(processId, ProcessState.STOPPED)
                }
            }
        }
    }
    
    fun killProcessOnPort(localPort: Int) {
        scope.launch {
            try {
                // Use lsof to find process using the port
                val lsofProcess = ProcessBuilder("lsof", "-ti", ":$localPort")
                    .redirectErrorStream(true)
                    .start()
                
                val pid = lsofProcess.inputStream.bufferedReader().readText().trim()
                lsofProcess.waitFor()
                
                if (pid.isNotEmpty()) {
                    // Kill the process
                    val killProcess = ProcessBuilder("kill", "-9", pid)
                        .redirectErrorStream(true)
                        .start()
                    
                    killProcess.waitFor()
                    println("🔍 [MCCService] Killed process $pid on port $localPort")
                } else {
                    println("🔍 [MCCService] No process found on port $localPort")
                }
            } catch (e: Exception) {
                println("🔍 [MCCService] Failed to kill process on port $localPort: ${e.message}")
            }
        }
    }

    fun getState(processId: UUID): ProcessState {
        return _portStates.value[processId] ?: ProcessState.STOPPED
    }

    private fun updateState(processId: UUID, state: ProcessState) {
        val currentStates = _portStates.value.toMutableMap()
        currentStates[processId] = state
        _portStates.value = currentStates
    }

    fun addLog(processId: UUID, message: String) {
        logs.getOrPut(processId) { mutableListOf() }.add(message)
    }

    fun getLogs(processId: UUID): List<String> {
        return logs[processId] ?: emptyList()
    }

    private fun startStateMonitoring() {
        scope.launch {
            while (true) {
                delay(1000)
                checkTimeouts()
            }
        }
    }

    private fun checkTimeouts() {
        val now = System.currentTimeMillis()
        val settings = settingsService.getSettings()
        val timeoutMs = settings.retryDelay * 2 * 1000L
        
        processStartTimes.forEach { (processId, startTime) ->
            val state = getState(processId)
            if ((state == ProcessState.CONNECTING || state == ProcessState.AUTHENTICATING) &&
                now - startTime > timeoutMs) {
                updateState(processId, ProcessState.TIMEOUT)
                addLog(processId, "Connection timeout")
            }
        }
    }

    private fun saveToStorage() {
        // TODO: Implement persistence
    }
    
    fun exportToJson(): String {
        val settings = settingsService.getSettings()
        
        val servicesJson = _services.value.joinToString(",\n    ") { service ->
            val hostsJson = service.hosts.joinToString(",\n      ") { host ->
                val locationsJson = host.locations.joinToString(",\n        ") { loc ->
                    """{"datacenter": "${loc.datacenter}", "localPort": ${loc.localPort}}"""
                }
                """
                {
                  "name": "${host.name}",
                  "hostnameTemplate": "${host.hostnameTemplate}",
                  "remotePort": ${host.remotePort},
                  "locations": [$locationsJson
                  ]
                }""".trimIndent()
            }
            """
            {
              "name": "${service.name}",
              "hosts": [$hostsJson
              ]
            }""".trimIndent()
        }
        
        return """
        {
          "version": "1.0",
          "services": [$servicesJson
          ],
          "settings": {
            "command": "${settings.command}",
            "loginCommand": "${settings.loginCommand}",
            "logoutCommand": "${settings.logoutCommand}",
            "retryEnabled": ${settings.retryEnabled},
            "retryAttempts": ${settings.retryAttempts},
            "retryDelay": ${settings.retryDelay},
            "datacenters": [${settings.datacenters.joinToString(", ") { "\"$it\"" }}]
          }
        }
        """.trimIndent()
    }
    
    fun importFromJson(json: String) {
        // Simple JSON parsing (basic implementation)
        try {
            // Stop all current services first
            _services.value.forEach { service ->
                service.hosts.forEach { host ->
                    host.compatiblePorts.forEach { port ->
                        stopPort(host, port)
                    }
                }
            }
            
            // TODO: Implement proper JSON parsing
            // For now, just show a message that it's not fully implemented
            println("🔍 [MCCService] Import JSON: ${json.take(100)}...")
            
        } catch (e: Exception) {
            println("🔍 [MCCService] Failed to import: ${e.message}")
            throw e
        }
    }

    fun dispose() {
        scope.cancel()
        processes.values.forEach { it.destroy() }
    }

    companion object {
        fun getInstance(): MCCPortForwarderService = service()
    }
}

