package com.mcc.portforwarder.dialogs

import com.intellij.openapi.project.Project
import com.intellij.openapi.ui.DialogWrapper
import com.intellij.openapi.ui.ValidationInfo
import com.intellij.ui.dsl.builder.*
import com.mcc.portforwarder.models.Host
import com.mcc.portforwarder.models.LocationMapping
import com.mcc.portforwarder.models.MCCServiceModel
import com.mcc.portforwarder.services.MCCService
import com.mcc.portforwarder.services.MCCSettings
import java.awt.Dimension
import java.util.*
import javax.swing.*

/**
 * DialogWrapper для добавления/редактирования хоста с чекбоксами для датацентров
 */
class AddHostDialog(
    private val project: Project,
    private val serviceId: UUID,
    private val editingHost: Host? = null
) : DialogWrapper(project) {
    
    private val hostNameField: JTextField = JTextField(editingHost?.name ?: "", 40)
    private val hostnameTemplateField: JTextField = JTextField(editingHost?.hostnameTemplate ?: "", 40)
    private val remotePortField: JTextField = JTextField(editingHost?.remotePort?.toString() ?: "5432", 10)
    private val startPortField: JTextField = JTextField("9000", 10)
    
    // Datacenter checkboxes and port fields
    private val datacenterCheckboxes: MutableMap<String, JCheckBox> = mutableMapOf()
    private val locationFields: MutableMap<String, JTextField> = mutableMapOf()
    
    init {
        title = if (editingHost != null) "Edit Host" else "Add Host"
        init()
    }
    
    override fun createCenterPanel(): JComponent {
        val settings = MCCSettings.getInstance()
        val service = MCCService.getInstance(project)
        
        return panel {
            row("Host Name:") {
                cell(hostNameField)
                    .focused()
                    .comment("Display name for this host")
            }
            
            row("Hostname Template:") {
                cell(hostnameTemplateField)
                    .comment("Use {location} placeholder (e.g., postgres-{location}.example.com)")
            }
            
            row("Remote Port:") {
                cell(remotePortField)
                    .comment("Port on the remote server")
            }
            
            separator()
            
            group("Location Mappings") {
                row("Start Port:") {
                    cell(startPortField)
                        .comment("Starting port for auto-assignment (e.g., 9000)")
                    button("Recalculate Ports") {
                        val startPort = startPortField.text.toIntOrNull() ?: 9000
                        var port = findNextAvailablePort(service, startPort)
                        locationFields.forEach { (dc, field) ->
                            val checkbox = datacenterCheckboxes[dc]
                            if (checkbox?.isSelected == true) {
                                field.text = port.toString()
                                port++
                            }
                        }
                    }
                }
                
                row {
                    comment("Select datacenters and assign local ports")
                }
                
                val datacenters = settings.getDatacenters()
                val startPort = startPortField.text.toIntOrNull() ?: 9000
                var nextPort = findNextAvailablePort(service, startPort)
                
                for (dc in datacenters) {
                    val existingLocation = editingHost?.locations?.firstOrNull { it.datacenter == dc }
                    val isChecked = existingLocation != null
                    val defaultPort = existingLocation?.localPort?.toString() ?: nextPort.toString()
                    
                    val checkbox = JCheckBox(dc, isChecked)
                    val portField = JTextField(defaultPort, 10)
                    portField.isEnabled = isChecked
                    
                    datacenterCheckboxes[dc] = checkbox
                    locationFields[dc] = portField
                    
                    // Enable/disable port field based on checkbox
                    checkbox.addActionListener {
                        portField.isEnabled = checkbox.isSelected
                        if (checkbox.isSelected && portField.text.isEmpty()) {
                            val startPort = startPortField.text.toIntOrNull() ?: 9000
                            portField.text = findNextAvailablePort(service, startPort).toString()
                        }
                    }
                    
                    row {
                        cell(checkbox)
                        cell(portField)
                            .comment("Local port for $dc")
                    }
                    
                    // Increment for next datacenter
                    if (!isChecked) {
                        nextPort++
                    }
                }
            }
        }.apply {
            preferredSize = Dimension(600, 500)
        }
    }
    
    override fun doValidate(): ValidationInfo? {
        // Don't validate until user tries to save - allows fixing errors
        return null
    }
    
    private fun validateBeforeSave(): ValidationInfo? {
        if (hostNameField.text.isBlank()) {
            return ValidationInfo("Host name cannot be empty", hostNameField)
        }
        if (hostnameTemplateField.text.isBlank()) {
            return ValidationInfo("Hostname template cannot be empty", hostnameTemplateField)
        }
        
        val remotePortInt = remotePortField.text.toIntOrNull()
        if (remotePortInt == null || remotePortInt !in 1..65535) {
            return ValidationInfo("Remote port must be valid (1-65535)", remotePortField)
        }
        
        // Check that at least one datacenter is selected
        val selectedDatacenters = datacenterCheckboxes.filter { it.value.isSelected }
        if (selectedDatacenters.isEmpty()) {
            return ValidationInfo("Please select at least one datacenter")
        }
        
        // Validate selected datacenter ports
        for ((dc, checkbox) in datacenterCheckboxes) {
            if (checkbox.isSelected) {
                val portField = locationFields[dc]!!
                val localPortInt = portField.text.toIntOrNull()
                if (localPortInt == null || localPortInt !in 1..65535) {
                    return ValidationInfo("Local port for $dc must be valid (1-65535)", portField)
                }
            }
        }
        
        return null
    }
    
    override fun doOKAction() {
        // Validate before saving
        val validationError = validateBeforeSave()
        if (validationError != null) {
            // Show error and focus on problematic field
            validationError.component?.requestFocusInWindow()
            setErrorText(validationError.message)
            return // Don't close dialog
        }
        
        val service = MCCService.getInstance(project)
        val remotePortInt = remotePortField.text.toInt()
        
        // Create locations only for selected datacenters
        val locations = datacenterCheckboxes
            .filter { it.value.isSelected }
            .map { (dc, _) ->
                val portField = locationFields[dc]!!
                LocationMapping(
                    datacenter = dc,
                    localPort = portField.text.toInt()
                )
            }
            .toMutableList()
        
        if (editingHost != null) {
            editingHost.name = hostNameField.text
            editingHost.hostnameTemplate = hostnameTemplateField.text
            editingHost.remotePort = remotePortInt
            editingHost.locations.clear()
            editingHost.locations.addAll(locations)
            service.updateHost(editingHost)
        } else {
            val newHost = Host(
                name = hostNameField.text,
                hostnameTemplate = hostnameTemplateField.text,
                remotePort = remotePortInt,
                locations = locations
            )
            service.addHostToService(serviceId, newHost)
        }
        
        super.doOKAction()
    }
    
    private fun findNextAvailablePort(service: MCCService, startPort: Int): Int {
        val usedPorts = mutableSetOf<Int>()
        for (srv in service.services.value) {
            for (host in srv.allHosts) {
                for (loc in host.locations) {
                    usedPorts.add(loc.localPort)
                }
            }
        }
        
        var port = startPort
        while (port in usedPorts) {
            port++
        }
        return port
    }
}
