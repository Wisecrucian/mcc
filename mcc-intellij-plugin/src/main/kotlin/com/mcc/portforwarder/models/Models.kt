package com.mcc.portforwarder.models

import java.nio.charset.StandardCharsets
import java.util.*

// ==================== ProcessState ====================

enum class ProcessState(val displayName: String, val emoji: String) {
    STOPPED("Stopped", "⚫"),
    RUNNING("Running", "🟢"),
    ERROR("Error", "🔴"),
    PORT_IN_USE("Port Busy", "🟡"),
    RESTARTING("Restarting", "🟠");
    
    val isActive: Boolean
        get() = this == RUNNING || this == RESTARTING
}

// ==================== PortMapping ====================

data class PortMapping(
    val id: UUID = UUID.randomUUID(),
    var fromPort: Int,  // Remote port on server
    var toPort: Int     // Local port on this machine
) {
    val displayString: String
        get() = "$fromPort → $toPort"
}

// ==================== LocationMapping ====================

data class LocationMapping(
    val id: UUID = UUID.randomUUID(),
    var datacenter: String,  // Reference to global datacenter name (e.g., "hc", "kc")
    var localPort: Int       // Local port on this machine (e.g., 9999)
) {
    // Generate process ID for this location
    fun processId(hostId: UUID): UUID {
        val combined = "$hostId-$id"
        return UUID.nameUUIDFromBytes(combined.toByteArray(StandardCharsets.UTF_8))
    }
}

// ==================== Host ====================

data class Host(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var hostnameTemplate: String,  // Can contain {location} placeholder
    var remotePort: Int,            // Remote port on server (e.g., 5432)
    var locations: MutableList<LocationMapping> = mutableListOf(),
    
    // Legacy fields for migration (optional, for backward compatibility)
    var hostname: String? = null,
    var tag: String? = null,
    var ports: MutableList<PortMapping>? = null
) {
    // Resolve hostname for a specific location
    fun resolvedHostname(location: LocationMapping): String =
        hostnameTemplate.replace("{location}", location.datacenter)
    
    // Generate unique ID for each location process
    fun processId(location: LocationMapping): UUID =
        location.processId(id)
    
    // Check if this host uses new structure
    val usesNewStructure: Boolean
        get() = locations.isNotEmpty()
    
    // Get ports - returns legacy ports or converts locations to ports
    val compatiblePorts: List<PortMapping>
        get() {
            if (!ports.isNullOrEmpty()) {
                return ports!!
            }
            // Convert locations to PortMapping format for compatibility
            return locations.map { location ->
                PortMapping(fromPort = remotePort, toPort = location.localPort)
            }
        }
    
    // Get hostname - returns legacy or template
    val compatibleHostname: String
        get() = hostname ?: hostnameTemplate
    
    // Process ID for legacy port mapping
    fun processId(port: PortMapping): UUID {
        // If using new structure, find matching location
        if (usesNewStructure) {
            locations.firstOrNull { it.localPort == port.toPort }?.let {
                return processId(it)
            }
        }
        // Legacy: deterministic UUID based on host ID and port ID
        val combined = "$id-${port.id}"
        return UUID.nameUUIDFromBytes(combined.toByteArray(StandardCharsets.UTF_8))
    }
}

// ==================== MCCService (модель) ====================

data class MCCServiceModel(
    val id: UUID = UUID.randomUUID(),
    var name: String,
    var hosts: MutableList<Host> = mutableListOf(),
    var childServices: MutableList<MCCServiceModel> = mutableListOf()
) {
    // Get all hosts recursively
    val allHosts: List<Host>
        get() {
            val result = mutableListOf<Host>()
            result.addAll(hosts)
            childServices.forEach { result.addAll(it.allHosts) }
            return result
        }
    
    // Count total hosts recursively
    val totalHostCount: Int
        get() = hosts.size + childServices.sumOf { it.totalHostCount }
}

// ==================== Configuration Export (БЕЗ UUID) ====================

data class ConfigurationExport(
    val version: String = "1.0",
    val datacenters: List<String>? = null,
    val services: List<MCCServiceExport>? = null
)

data class MCCServiceExport(
    val name: String,
    val hosts: List<HostExport>? = null,
    val childServices: List<MCCServiceExport>? = null
)

data class HostExport(
    val name: String,
    val hostnameTemplate: String,
    val remotePort: Int,
    val locations: List<LocationMappingExport>? = null
)

data class LocationMappingExport(
    val datacenter: String,
    val localPort: Int
)

