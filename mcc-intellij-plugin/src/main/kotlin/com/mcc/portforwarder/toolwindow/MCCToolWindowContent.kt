package com.mcc.portforwarder.toolwindow

import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory
import com.intellij.openapi.fileChooser.FileChooserFactory
import com.intellij.openapi.project.Project
import com.intellij.openapi.ui.Messages
import com.intellij.ui.components.JBScrollPane
import com.intellij.ui.treeStructure.Tree
import com.mcc.portforwarder.models.*
import com.mcc.portforwarder.services.MCCPortForwarderService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import java.awt.BorderLayout
import java.io.File
import javax.swing.*
import javax.swing.tree.DefaultMutableTreeNode
import javax.swing.tree.DefaultTreeModel

class MCCToolWindowContent(private val project: Project) {
    private val service = MCCPortForwarderService.getInstance()
    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    
    private val tree = Tree()
    private val treeModel = DefaultTreeModel(DefaultMutableTreeNode("Services"))
    
    init {
        tree.model = treeModel
        tree.isRootVisible = false
        tree.showsRootHandles = true
        
        // Subscribe to services updates
        service.services.onEach { services ->
            SwingUtilities.invokeLater {
                updateTree()
            }
        }.launchIn(scope)
        
        // Subscribe to state updates
        service.portStates.onEach { states ->
            SwingUtilities.invokeLater {
                updateTree()
            }
        }.launchIn(scope)
    }
    
    fun getContent(): JComponent {
        val panel = JPanel(BorderLayout())
        
        // Toolbar
        val toolbar = createToolbar()
        panel.add(toolbar, BorderLayout.NORTH)
        
        // Tree with message
        val centerPanel = JPanel(BorderLayout())
        val scrollPane = JBScrollPane(tree)
        centerPanel.add(scrollPane, BorderLayout.CENTER)
        
        // Add helper text when empty
        if (service.services.value.isEmpty()) {
            val helpLabel = JLabel("<html><center>No services configured<br><br>Click 'Add Test Data' to get started<br>or 'Import' to load configuration</center></html>")
            helpLabel.horizontalAlignment = SwingConstants.CENTER
            centerPanel.add(helpLabel, BorderLayout.SOUTH)
        }
        
        panel.add(centerPanel, BorderLayout.CENTER)
        
        return panel
    }
    
    private fun createToolbar(): JComponent {
        val toolbar = JPanel()
        toolbar.layout = BoxLayout(toolbar, BoxLayout.X_AXIS)
        toolbar.border = BorderFactory.createEmptyBorder(5, 5, 5, 5)
        
        // Add Test Data button
        val testDataButton = JButton("Add Test Data")
        testDataButton.toolTipText = "Add sample service for testing"
        testDataButton.addActionListener {
            addTestData()
        }
        toolbar.add(testDataButton)
        
        toolbar.add(Box.createHorizontalStrut(5))
        
        // Import button
        val importButton = JButton("Import")
        importButton.toolTipText = "Import configuration from JSON file"
        importButton.addActionListener {
            importConfiguration()
        }
        toolbar.add(importButton)
        
        toolbar.add(Box.createHorizontalGlue())
        
        // Settings button
        val settingsButton = JButton("Settings")
        settingsButton.addActionListener {
            showSettings()
        }
        toolbar.add(settingsButton)
        
        return toolbar
    }
    
    private fun addTestData() {
        val testService = com.mcc.portforwarder.models.Service(
            name = "Test Service"
        )
        
        val location1 = LocationMapping(datacenter = "dc1", localPort = 9001)
        val location2 = LocationMapping(datacenter = "dc2", localPort = 9002)
        
        val testHost = Host(
            name = "Test Host",
            hostnameTemplate = "test.example.{location}.com",
            remotePort = 8080,
            locations = listOf(location1, location2)
        )
        
        testService.hosts.add(testHost)
        service.addService(testService)
        
        Messages.showInfoMessage(
            "Test service added successfully!\n\nService: ${testService.name}\nHost: ${testHost.name}\nPorts: 8080→9001 (dc1), 8080→9002 (dc2)",
            "Test Data Added"
        )
    }
    
    private fun importConfiguration() {
        val descriptor = FileChooserDescriptorFactory.createSingleFileDescriptor("json")
        descriptor.title = "Select Configuration File"
        descriptor.description = "Choose a JSON configuration file to import"
        
        val chooser = FileChooserFactory.getInstance().createFileChooser(descriptor, project, null)
        val files = chooser.choose(project)
        
        if (files.isNotEmpty()) {
            try {
                val file = File(files[0].path)
                val content = file.readText()
                // TODO: Parse and import JSON configuration
                Messages.showInfoMessage("Import from JSON not yet implemented.\nPlease use 'Add Test Data' for now.", "Import")
            } catch (e: Exception) {
                Messages.showErrorDialog("Failed to import configuration: ${e.message}", "Import Error")
            }
        }
    }
    
    private fun showSettings() {
        val settingsService = com.mcc.portforwarder.services.MCCSettingsService.getInstance()
        val settings = settingsService.getSettings()
        
        val message = """
            Current Settings:
            
            Command: ${settings.command}
            Login Command: ${settings.loginCommand}
            Logout Command: ${settings.logoutCommand}
            
            Retry Enabled: ${settings.retryEnabled}
            Retry Attempts: ${settings.retryAttempts}
            Retry Delay: ${settings.retryDelay}s
            
            Datacenters: ${settings.datacenters.joinToString(", ")}
        """.trimIndent()
        
        Messages.showInfoMessage(message, "Settings")
    }
    
    private fun updateTree() {
        val root = treeModel.root as DefaultMutableTreeNode
        root.removeAllChildren()
        
        service.services.value.forEach { svc ->
            val serviceNode = DefaultMutableTreeNode(svc.name)
            root.add(serviceNode)
            
            svc.hosts.forEach { host ->
                val hostNode = DefaultMutableTreeNode("${host.name} (${host.compatiblePorts.size} ports)")
                serviceNode.add(hostNode)
                
                host.compatiblePorts.forEach { port ->
                    val processId = host.processId(port)
                    val state = service.getState(processId)
                    val portNode = DefaultMutableTreeNode(
                        "${state.emoji} ${port.fromPort}→${port.toPort} [${state.displayName}]"
                    )
                    hostNode.add(portNode)
                }
            }
        }
        
        treeModel.reload()
        expandAll()
    }
    
    private fun expandAll() {
        for (i in 0 until tree.rowCount) {
            tree.expandRow(i)
        }
    }
}

