package com.mcc.portforwarder.dialogs

import com.google.gson.GsonBuilder
import com.intellij.notification.Notification
import com.intellij.notification.NotificationType
import com.intellij.notification.Notifications
import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory
import com.intellij.openapi.project.Project
import com.intellij.openapi.ui.DialogWrapper
import com.intellij.ui.components.JBList
import com.intellij.ui.components.JBScrollPane
import com.intellij.ui.components.JBTextArea
import com.intellij.ui.dsl.builder.*
import com.mcc.portforwarder.services.MCCService
import com.mcc.portforwarder.services.MCCSettings
import java.awt.Dimension
import java.io.File
import javax.swing.DefaultListModel
import javax.swing.JButton
import javax.swing.JComponent
import javax.swing.JOptionPane
import javax.swing.JPanel
import java.awt.BorderLayout
import java.awt.FlowLayout

/**
 * Settings Dialog с импортом/экспортом
 */
class SettingsDialog(private val project: Project) : DialogWrapper(project) {
    
    private val settings = MCCSettings.getInstance()
    private val service = MCCService.getInstance(project)
    
    // Settings fields
    private val datacentersListModel = DefaultListModel<String>()
    private var forwardCommand: String = settings.forwardCommand
    private var loginCommand: String = settings.loginCommand
    private var logoutCommand: String = settings.logoutCommand
    private var retryEnabled: Boolean = settings.retryEnabled
    private var retryAttempts: String = settings.retryAttempts.toString()
    private var retryDelay: String = settings.retryDelay.toString()
    
    init {
        title = "MCC Port Forwarder Settings"
        
        // Initialize datacenters list
        settings.getDatacenters().forEach { dc ->
            datacentersListModel.addElement(dc)
        }
        
        init()
    }
    
    override fun createCenterPanel(): JComponent {
        return panel {
            group("Datacenters") {
                row {
                    val dcList = JBList(datacentersListModel)
                    dcList.visibleRowCount = 5
                    
                    val listPanel = JPanel(BorderLayout())
                    listPanel.add(JBScrollPane(dcList), BorderLayout.CENTER)
                    
                    val buttonsPanel = JPanel(FlowLayout(FlowLayout.LEFT))
                    
                    val addButton = JButton("+")
                    addButton.toolTipText = "Add datacenter"
                    addButton.addActionListener {
                        val newDc = JOptionPane.showInputDialog(
                            listPanel,
                            "Enter datacenter name:",
                            "Add Datacenter",
                            JOptionPane.PLAIN_MESSAGE
                        )
                        if (newDc != null && newDc.isNotBlank()) {
                            val trimmedDc = newDc.trim()
                            if (!datacentersListModel.contains(trimmedDc)) {
                                datacentersListModel.addElement(trimmedDc)
                            }
                        }
                    }
                    
                    val removeButton = JButton("-")
                    removeButton.toolTipText = "Remove selected datacenter"
                    removeButton.addActionListener {
                        val selected = dcList.selectedValue
                        if (selected != null) {
                            datacentersListModel.removeElement(selected)
                        }
                    }
                    
                    buttonsPanel.add(addButton)
                    buttonsPanel.add(removeButton)
                    listPanel.add(buttonsPanel, BorderLayout.SOUTH)
                    
                    cell(listPanel)
                        .comment("Datacenters for location mappings")
                }
            }
            
            group("Commands") {
                row("Port Forward Command:") {
                    textField()
                        .text(forwardCommand)
                        .columns(40)
                        .apply {
                            component.addActionListener {
                                forwardCommand = component.text
                            }
                        }
                }
                
                row("Login Command:") {
                    textField()
                        .text(loginCommand)
                        .columns(40)
                        .apply {
                            component.addActionListener {
                                loginCommand = component.text
                            }
                        }
                }
                
                row("Logout Command:") {
                    textField()
                        .text(logoutCommand)
                        .columns(40)
                        .apply {
                            component.addActionListener {
                                logoutCommand = component.text
                            }
                        }
                }
            }
            
            group("Configuration") {
                row {
                    button("Import from JSON...") {
                        importConfiguration()
                    }
                    button("Export to JSON...") {
                        exportConfiguration()
                    }
                }
            }
            
            group("Logs") {
                row {
                    button("View Application Logs") {
                        AppLogsDialog(project).show()
                    }.comment("View plugin actions and system logs")
                }
            }
        }
    }
    
    override fun doOKAction() {
        val dcList = mutableListOf<String>()
        for (i in 0 until datacentersListModel.size()) {
            dcList.add(datacentersListModel.getElementAt(i))
        }
        settings.replaceDatacenters(dcList)
        
        settings.forwardCommand = forwardCommand
        settings.loginCommand = loginCommand
        settings.logoutCommand = logoutCommand
        
        settings.retryEnabled = retryEnabled
        settings.retryAttempts = retryAttempts.toIntOrNull() ?: 3
        settings.retryDelay = retryDelay.toIntOrNull() ?: 5
        
        super.doOKAction()
    }
    
    private fun importConfiguration() {
        service.logApp("📥 Import: Opening file chooser...")
        val descriptor = FileChooserDescriptorFactory.createSingleFileDescriptor("json")
        descriptor.title = "Select Configuration File"
        
        val chooser = com.intellij.openapi.fileChooser.FileChooser.chooseFile(descriptor, project, null)
        if (chooser != null) {
            service.logApp("📥 Import: Selected file: ${chooser.path}")
            try {
                val content = File(chooser.path).readText()
                service.logApp("📥 Import: File size: ${content.length} bytes")
                
                val gson = GsonBuilder().create()
                val config = gson.fromJson(content, com.mcc.portforwarder.models.ConfigurationExport::class.java)
                
                val servicesCount = config.services?.size ?: 0
                val datacentersCount = config.datacenters?.size ?: 0
                service.logApp("📥 Import: Parsed JSON - $servicesCount services, $datacentersCount datacenters")
                
                if (servicesCount == 0) {
                    service.logApp("⚠️ Import: No services found in configuration", true)
                }
                
                service.importConfiguration(config)
                
                // Update datacenters list
                datacentersListModel.clear()
                settings.getDatacenters().forEach { dc ->
                    datacentersListModel.addElement(dc)
                }
                
                service.logApp("✅ Import: Successfully imported configuration from ${chooser.name}")
                Notifications.Bus.notify(
                    Notification(
                        "MCC",
                        "Import Successful",
                        "Configuration imported: $servicesCount services",
                        NotificationType.INFORMATION
                    )
                )
            } catch (e: Exception) {
                service.logApp("❌ Import: Failed - ${e.message}", true)
                e.printStackTrace()
                Notifications.Bus.notify(
                    Notification(
                        "MCC",
                        "Import Failed",
                        "Failed to import configuration: ${e.message}",
                        NotificationType.ERROR
                    )
                )
            }
        } else {
            service.logApp("📥 Import: Cancelled by user")
        }
    }
    
    private fun exportConfiguration() {
        service.logApp("📤 Export: Opening save dialog...")
        
        val descriptor = FileChooserDescriptorFactory.createSingleFolderDescriptor()
        descriptor.title = "Select Directory to Save Configuration"
        
        val chooser = com.intellij.openapi.fileChooser.FileChooser.chooseFile(descriptor, project, null)
        if (chooser != null) {
            try {
                val config = service.exportConfiguration()
                val gson = GsonBuilder().setPrettyPrinting().create()
                val json = gson.toJson(config)
                
                val fileName = "mcc-config-${System.currentTimeMillis()}.json"
                val file = File(chooser.path, fileName)
                file.writeText(json)
                
                service.logApp("✅ Export: Configuration exported to ${file.absolutePath}")
                Notifications.Bus.notify(
                    Notification(
                        "MCC",
                        "Export Successful",
                        "Configuration exported to ${file.absolutePath}",
                        NotificationType.INFORMATION
                    )
                )
            } catch (e: Exception) {
                service.logApp("❌ Export: Failed - ${e.message}", true)
                e.printStackTrace()
                Notifications.Bus.notify(
                    Notification(
                        "MCC",
                        "Export Failed",
                        "Failed to export configuration: ${e.message}",
                        NotificationType.ERROR
                    )
                )
            }
        } else {
            service.logApp("📤 Export: Cancelled by user")
        }
    }
}

/**
 * Application Logs Dialog
 */
class AppLogsDialog(private val project: Project) : DialogWrapper(project) {
    
    private val service = MCCService.getInstance(project)
    
    init {
        title = "Application Logs"
        init()
    }
    
    override fun createCenterPanel(): JComponent {
        val logs = service.appLogs.value.joinToString("\n")
        val textArea = JBTextArea(logs)
        textArea.isEditable = false
        textArea.rows = 20
        textArea.columns = 80
        
        val scrollPane = JBScrollPane(textArea)
        scrollPane.preferredSize = Dimension(800, 400)
        
        return scrollPane
    }
}
