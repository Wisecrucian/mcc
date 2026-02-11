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
    private val mainPanel = JPanel(BorderLayout())
    private val centerPanel = JPanel(BorderLayout())
    
    init {
        tree.model = treeModel
        tree.isRootVisible = false
        tree.showsRootHandles = true
        
        // Subscribe to services updates
        service.services.onEach { services ->
            SwingUtilities.invokeLater {
                updateTree()
                updateEmptyState()
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
        // Toolbar
        val toolbar = createToolbar()
        mainPanel.add(toolbar, BorderLayout.NORTH)
        
        // Tree
        val scrollPane = JBScrollPane(tree)
        centerPanel.add(scrollPane, BorderLayout.CENTER)
        
        mainPanel.add(centerPanel, BorderLayout.CENTER)
        
        // Initial state check
        updateEmptyState()
        
        return mainPanel
    }
    
    private fun updateEmptyState() {
        println("🔍 [MCCToolWindow] updateEmptyState() called")
        println("🔍 [MCCToolWindow] Services count: ${service.services.value.size}")
        
        // Remove old help label if exists
        centerPanel.components.forEach { 
            if (it is JLabel) {
                println("🔍 [MCCToolWindow] Removing old help label")
                centerPanel.remove(it)
            }
        }
        
        // Add helper text when empty
        if (service.services.value.isEmpty()) {
            println("🔍 [MCCToolWindow] Services empty, adding help label")
            val helpLabel = JLabel("<html><center><h2>No services configured</h2><br><br>Click <b>'Add Test Data'</b> to get started<br>or <b>'Import'</b> to load configuration</center></html>")
            helpLabel.horizontalAlignment = SwingConstants.CENTER
            centerPanel.add(helpLabel, BorderLayout.SOUTH)
        } else {
            println("🔍 [MCCToolWindow] Services not empty, no help label needed")
        }
        
        centerPanel.revalidate()
        centerPanel.repaint()
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
        println("🔍 [MCCToolWindow] addTestData() called")
        
        val testService = com.mcc.portforwarder.models.Service(
            name = "Test Service"
        )
        println("🔍 [MCCToolWindow] Created service: ${testService.name}, id: ${testService.id}")
        
        val location1 = LocationMapping(datacenter = "dc1", localPort = 9001)
        val location2 = LocationMapping(datacenter = "dc2", localPort = 9002)
        println("🔍 [MCCToolWindow] Created locations: dc1, dc2")
        
        val testHost = Host(
            name = "Test Host",
            hostnameTemplate = "test.example.{location}.com",
            remotePort = 8080,
            locations = listOf(location1, location2)
        )
        println("🔍 [MCCToolWindow] Created host: ${testHost.name}, id: ${testHost.id}")
        
        testService.hosts.add(testHost)
        println("🔍 [MCCToolWindow] Added host to service. Service hosts count: ${testService.hosts.size}")
        
        service.addService(testService)
        println("🔍 [MCCToolWindow] Added service. Total services: ${service.services.value.size}")
        
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
        println("🔍 [MCCToolWindow] updateTree() called")
        val root = treeModel.root as DefaultMutableTreeNode
        root.removeAllChildren()
        
        println("🔍 [MCCToolWindow] Services count: ${service.services.value.size}")
        
        service.services.value.forEach { svc ->
            println("🔍 [MCCToolWindow] Processing service: ${svc.name}, hosts: ${svc.hosts.size}")
            val serviceNode = DefaultMutableTreeNode(svc.name)
            root.add(serviceNode)
            
            svc.hosts.forEach { host ->
                println("🔍 [MCCToolWindow] Processing host: ${host.name}, ports: ${host.compatiblePorts.size}")
                val hostNode = DefaultMutableTreeNode("${host.name} (${host.compatiblePorts.size} ports)")
                serviceNode.add(hostNode)
                
                host.compatiblePorts.forEach { port ->
                    val processId = host.processId(port)
                    val state = service.getState(processId)
                    println("🔍 [MCCToolWindow] Processing port: ${port.fromPort}→${port.toPort}, state: ${state.displayName}")
                    val portNode = DefaultMutableTreeNode(
                        "${state.emoji} ${port.fromPort}→${port.toPort} [${state.displayName}]"
                    )
                    hostNode.add(portNode)
                }
            }
        }
        
        println("🔍 [MCCToolWindow] Root children count: ${root.childCount}")
        treeModel.reload()
        expandAll()
        println("🔍 [MCCToolWindow] Tree updated and expanded")
    }
    
    private fun expandAll() {
        for (i in 0 until tree.rowCount) {
            tree.expandRow(i)
        }
    }
}

