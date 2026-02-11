package com.mcc.portforwarder.models

import java.util.UUID

// Process State
enum class ProcessState {
    STOPPED,
    CONNECTING,
    AUTHENTICATING,
    READY,
    ERROR,
    TIMEOUT,
    PORT_IN_USE,
    RESTARTING,
    DISCONNECTED;

    val displayName: String
        get() = when (this) {
            STOPPED -> "Stopped"
            CONNECTING -> "Connecting"
            AUTHENTICATING -> "Authenticating"
            READY -> "Ready"
            ERROR -> "Error"
            TIMEOUT -> "Timeout"
            PORT_IN_USE -> "Port Busy"
            RESTARTING -> "Restarting"
            DISCONNECTED -> "Disconnected"
        }

    val emoji: String
        get() = when (this) {
            STOPPED -> "⚪"
            CONNECTING -> "🔵"
            AUTHENTICATING -> "🟡"
            READY -> "🟢"
            ERROR -> "🔴"
            TIMEOUT -> "🟠"
            PORT_IN_USE -> "🟠"
            RESTARTING -> "🔄"
            DISCONNECTED -> "🟣"
        }

    val isActive: Boolean
        get() = when (this) {
            CONNECTING, AUTHENTICATING, READY, RESTARTING -> true
            else -> false
        }

    val priority: Int
        get() = when (this) {
            STOPPED -> 0
            READY -> 1
            CONNECTING -> 2
            AUTHENTICATING -> 3
            RESTARTING -> 4
            DISCONNECTED -> 5
            TIMEOUT -> 6
            PORT_IN_USE -> 7
            ERROR -> 8
        }

    companion object {
        fun fromLogMessage(message: String): ProcessState? {
            val lowercased = message.lowercase()

            return when {
                lowercased.contains("address already in use") ||
                        lowercased.contains("port is already allocated") -> PORT_IN_USE

                lowercased.contains("error:") ||
                        lowercased.contains("failed:") ||
                        lowercased.contains("refused") ||
                        lowercased.contains("denied") -> ERROR

                lowercased.contains("timeout") ||
                        lowercased.contains("timed out") -> TIMEOUT

                lowercased.contains("proxying connections to") ||
                        lowercased.contains("forwarding from") ||
                        lowercased.contains("established") -> READY

                lowercased.contains("authentication") ||
                        lowercased.contains("authenticating") ||
                        lowercased.contains("login") ||
                        lowercased.contains("opening browser") -> AUTHENTICATING

                else -> null
            }
        }
    }
}

// Location Mapping
data class LocationMapping(
    val id: UUID = UUID.randomUUID(),
    val datacenter: String,
    val localPort: Int
)

// Port Mapping
data class PortMapping(
    val id: UUID = UUID.randomUUID(),
    val fromPort: Int,  // remote port
    val toPort: Int     // local port
)

// Host
data class Host(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var hostnameTemplate: String = "",
    var remotePort: Int = 0,
    var locations: List<LocationMapping> = emptyList(),
    var tag: String? = null,
    
    // Legacy support
    var hostname: String = "",
    var ports: List<PortMapping> = emptyList()
) {
    val usesNewStructure: Boolean
        get() = locations.isNotEmpty()

    val compatiblePorts: List<PortMapping>
        get() = if (usesNewStructure) {
            locations.map { location ->
                PortMapping(
                    fromPort = remotePort,
                    toPort = location.localPort
                )
            }
        } else {
            ports
        }

    val compatibleHostname: String
        get() = if (usesNewStructure) hostnameTemplate else hostname

    fun resolvedHostname(location: LocationMapping): String {
        return hostnameTemplate.replace("{location}", location.datacenter, ignoreCase = true)
    }

    fun processId(port: PortMapping): UUID {
        if (usesNewStructure) {
            val location = locations.find { it.localPort == port.toPort }
            if (location != null) {
                return UUID.nameUUIDFromBytes("${id}_${location.id}".toByteArray())
            }
        }
        return UUID.nameUUIDFromBytes("${id}_${port.id}".toByteArray())
    }
}

// Service
data class Service(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var hosts: MutableList<Host> = mutableListOf(),
    var childServices: MutableList<Service> = mutableListOf()
) {
    fun getAllHosts(): List<Host> {
        val allHosts = mutableListOf<Host>()
        allHosts.addAll(hosts)
        childServices.forEach { allHosts.addAll(it.getAllHosts()) }
        return allHosts
    }
}

// Configuration Export/Import models
data class ConfigurationExport(
    val version: String = "1.0",
    val exportDate: Long = System.currentTimeMillis(),
    val services: List<ServiceExport>,
    val settings: SettingsExport
)

data class ServiceExport(
    val name: String,
    val hosts: List<HostExport>,
    val childServices: List<ServiceExport>
)

data class HostExport(
    val name: String,
    val hostnameTemplate: String,
    val remotePort: Int,
    val locations: List<LocationMappingExport>
)

data class LocationMappingExport(
    val datacenter: String,
    val localPort: Int
)

data class SettingsExport(
    val command: String,
    val loginCommand: String,
    val logoutCommand: String,
    val retryEnabled: Boolean,
    val retryAttempts: Int,
    val retryDelay: Int,
    val datacenters: List<String>
)

