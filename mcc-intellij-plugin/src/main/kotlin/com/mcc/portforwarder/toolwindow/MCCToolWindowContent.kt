package com.mcc.portforwarder.toolwindow

import com.intellij.openapi.fileChooser.FileChooserDescriptorFactory
import com.intellij.openapi.fileChooser.FileChooserFactory
import com.intellij.openapi.project.Project
import com.intellij.openapi.ui.Messages
import com.intellij.ui.components.JBScrollPane
import com.intellij.ui.treeStructure.Tree
import com.mcc.portforwarder.models.*
import com.mcc.portforwarder.services.MCCPortForwarderService
import com.mcc.portforwarder.services.MCCSettingsService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
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
        
        // Add context menu
        setupContextMenu()
        
        // Add double-click handler
        tree.addMouseListener(object : java.awt.event.MouseAdapter() {
            override fun mouseClicked(e: java.awt.event.MouseEvent) {
                if (e.clickCount == 2) {
                    handleDoubleClick()
                }
            }
        })
        
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
        
        // Start All button
        val startAllButton = JButton("▶️ Start All")
        startAllButton.toolTipText = "Start all services"
        startAllButton.addActionListener {
            service.services.value.forEach { svc ->
                svc.hosts.forEach { host ->
                    host.compatiblePorts.forEach { port ->
                        service.startPort(host, port)
                    }
                }
            }
        }
        toolbar.add(startAllButton)
        
        toolbar.add(Box.createHorizontalStrut(5))
        
        // Stop All button
        val stopAllButton = JButton("⏹️ Stop All")
        stopAllButton.toolTipText = "Stop all running services"
        stopAllButton.addActionListener {
            service.services.value.forEach { svc ->
                svc.hosts.forEach { host ->
                    host.compatiblePorts.forEach { port ->
                        service.stopPort(host, port)
                    }
                }
            }
        }
        toolbar.add(stopAllButton)
        
        toolbar.add(Box.createHorizontalStrut(10))
        toolbar.add(JSeparator(SwingConstants.VERTICAL))
        toolbar.add(Box.createHorizontalStrut(10))
        
        // Login button
        val loginButton = JButton("🔐 Login")
        loginButton.toolTipText = "Execute login command"
        loginButton.addActionListener {
            executeLoginCommand()
        }
        toolbar.add(loginButton)
        
        toolbar.add(Box.createHorizontalStrut(5))
        
        // Logout button
        val logoutButton = JButton("🚪 Logout")
        logoutButton.toolTipText = "Execute logout command"
        logoutButton.addActionListener {
            executeLogoutCommand()
        }
        toolbar.add(logoutButton)
        
        toolbar.add(Box.createHorizontalStrut(10))
        toolbar.add(JSeparator(SwingConstants.VERTICAL))
        toolbar.add(Box.createHorizontalStrut(10))
        
        // Add Test Data button
        val testDataButton = JButton("➕ Add Test Data")
        testDataButton.toolTipText = "Add sample service for testing"
        testDataButton.addActionListener {
            addTestData()
        }
        toolbar.add(testDataButton)
        
        toolbar.add(Box.createHorizontalStrut(5))
        
        // Import button
        val importButton = JButton("📥 Import")
        importButton.toolTipText = "Import configuration from JSON file"
        importButton.addActionListener {
            importConfiguration()
        }
        toolbar.add(importButton)
        
        toolbar.add(Box.createHorizontalStrut(5))
        
        // Export button
        val exportButton = JButton("📤 Export")
        exportButton.toolTipText = "Export configuration to JSON file"
        exportButton.addActionListener {
            exportConfiguration()
        }
        toolbar.add(exportButton)
        
        toolbar.add(Box.createHorizontalGlue())
        
        // Active connections label
        val activeLabel = JLabel("Active: 0")
        activeLabel.toolTipText = "Number of active connections"
        toolbar.add(activeLabel)
        
        // Update active connections counter
        service.portStates.onEach { states ->
            SwingUtilities.invokeLater {
                val activeCount = states.values.count { it == ProcessState.READY }
                activeLabel.text = "Active: $activeCount"
            }
        }.launchIn(scope)
        
        toolbar.add(Box.createHorizontalStrut(10))
        
        // Settings button
        val settingsButton = JButton("⚙️ Settings")
        settingsButton.addActionListener {
            showSettings()
        }
        toolbar.add(settingsButton)
        
        return toolbar
    }
    
    private fun executeLoginCommand() {
        scope.launch {
            try {
                val settings = MCCSettingsService.getInstance().getSettings()
                val process = ProcessBuilder(settings.loginCommand.split(" "))
                    .redirectErrorStream(true)
                    .start()
                
                val output = process.inputStream.bufferedReader().readText()
                val exitCode = process.waitFor()
                
                SwingUtilities.invokeLater {
                    if (exitCode == 0) {
                        Messages.showInfoMessage(project, "Login successful!\n\n$output", "Login")
                    } else {
                        Messages.showErrorDialog(project, "Login failed!\n\n$output", "Login Error")
                    }
                }
            } catch (e: Exception) {
                SwingUtilities.invokeLater {
                    Messages.showErrorDialog(project, "Failed to execute login command: ${e.message}", "Login Error")
                }
            }
        }
    }
    
    private fun executeLogoutCommand() {
        scope.launch {
            try {
                val settings = MCCSettingsService.getInstance().getSettings()
                val process = ProcessBuilder(settings.logoutCommand.split(" "))
                    .redirectErrorStream(true)
                    .start()
                
                val output = process.inputStream.bufferedReader().readText()
                val exitCode = process.waitFor()
                
                SwingUtilities.invokeLater {
                    if (exitCode == 0) {
                        Messages.showInfoMessage(project, "Logout successful!\n\n$output", "Logout")
                    } else {
                        Messages.showErrorDialog(project, "Logout failed!\n\n$output", "Logout Error")
                    }
                }
            } catch (e: Exception) {
                SwingUtilities.invokeLater {
                    Messages.showErrorDialog(project, "Failed to execute logout command: ${e.message}", "Logout Error")
                }
            }
        }
    }
    
    private fun exportConfiguration() {
        val descriptor = FileChooserDescriptorFactory.createSingleFolderDescriptor()
        descriptor.title = "Select Export Directory"
        descriptor.description = "Choose where to save the configuration file"
        
        val chooser = FileChooserFactory.getInstance().createFileChooser(descriptor, project, null)
        val files = chooser.choose(project)
        
        if (files.isNotEmpty()) {
            try {
                val dir = java.io.File(files[0].path)
                val file = java.io.File(dir, "mcc-config-export.json")
                
                val json = service.exportToJson()
                file.writeText(json)
                
                Messages.showInfoMessage(
                    project,
                    "Configuration exported successfully!\n\nFile: ${file.absolutePath}\nServices: ${service.services.value.size}",
                    "Export Successful"
                )
            } catch (e: Exception) {
                Messages.showErrorDialog(project, "Failed to export configuration: ${e.message}", "Export Error")
            }
        }
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
                
                service.importFromJson(content)
                
                Messages.showInfoMessage(
                    project,
                    "Configuration imported successfully!\n\nNote: Full JSON parsing is not yet implemented.\nUse 'Add Test Data' to add services.",
                    "Import"
                )
            } catch (e: Exception) {
                Messages.showErrorDialog(project, "Failed to import configuration: ${e.message}", "Import Error")
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
            
            val serviceData = TreeNodeData(
                type = TreeNodeType.SERVICE,
                label = svc.name,
                serviceId = svc.id
            )
            val serviceNode = DefaultMutableTreeNode(serviceData)
            root.add(serviceNode)
            
            svc.hosts.forEach { host ->
                println("🔍 [MCCToolWindow] Processing host: ${host.name}, ports: ${host.compatiblePorts.size}")
                
                val hostData = TreeNodeData(
                    type = TreeNodeType.HOST,
                    label = "${host.name} (${host.compatiblePorts.size} ports)",
                    serviceId = svc.id,
                    hostId = host.id
                )
                val hostNode = DefaultMutableTreeNode(hostData)
                serviceNode.add(hostNode)
                
                host.compatiblePorts.forEach { port ->
                    val processId = host.processId(port)
                    val state = service.getState(processId)
                    println("🔍 [MCCToolWindow] Processing port: ${port.fromPort}→${port.toPort}, state: ${state.displayName}")
                    
                    val portData = TreeNodeData(
                        type = TreeNodeType.PORT,
                        label = "${state.emoji} ${port.fromPort}→${port.toPort} [${state.displayName}]",
                        serviceId = svc.id,
                        hostId = host.id,
                        portId = port.id,
                        state = state
                    )
                    val portNode = DefaultMutableTreeNode(portData)
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
    
    private fun setupContextMenu() {
        val popupMenu = JPopupMenu()
        
        val startItem = JMenuItem("Start")
        startItem.addActionListener { handleStartPort() }
        popupMenu.add(startItem)
        
        val stopItem = JMenuItem("Stop")
        stopItem.addActionListener { handleStopPort() }
        popupMenu.add(stopItem)
        
        popupMenu.addSeparator()
        
        val killItem = JMenuItem("Kill Process on Port")
        killItem.addActionListener { handleKillProcess() }
        popupMenu.add(killItem)
        
        popupMenu.addSeparator()
        
        val logsItem = JMenuItem("View Logs")
        logsItem.addActionListener { handleViewLogs() }
        popupMenu.add(logsItem)
        
        // Show context menu on right-click
        tree.addMouseListener(object : java.awt.event.MouseAdapter() {
            override fun mousePressed(e: java.awt.event.MouseEvent) {
                if (e.isPopupTrigger) {
                    showContextMenu(e, popupMenu)
                }
            }
            
            override fun mouseReleased(e: java.awt.event.MouseEvent) {
                if (e.isPopupTrigger) {
                    showContextMenu(e, popupMenu)
                }
            }
            
            private fun showContextMenu(e: java.awt.event.MouseEvent, menu: JPopupMenu) {
                val path = tree.getPathForLocation(e.x, e.y)
                if (path != null) {
                    tree.selectionPath = path
                    val node = path.lastPathComponent as? DefaultMutableTreeNode
                    val data = node?.userObject as? TreeNodeData
                    
                    // Enable/disable menu items based on node type and state
                    when (data?.type) {
                        TreeNodeType.PORT -> {
                            startItem.isEnabled = data.state != ProcessState.READY
                            stopItem.isEnabled = data.state != ProcessState.STOPPED
                            killItem.isEnabled = true
                            logsItem.isEnabled = true
                        }
                        TreeNodeType.HOST -> {
                            startItem.isEnabled = true
                            startItem.text = "Start All Ports"
                            stopItem.isEnabled = true
                            stopItem.text = "Stop All Ports"
                            killItem.isEnabled = false
                            logsItem.isEnabled = false
                        }
                        TreeNodeType.SERVICE -> {
                            startItem.isEnabled = true
                            startItem.text = "Start Service"
                            stopItem.isEnabled = true
                            stopItem.text = "Stop Service"
                            killItem.isEnabled = false
                            logsItem.isEnabled = false
                        }
                        else -> return
                    }
                    
                    menu.show(tree, e.x, e.y)
                }
            }
        })
    }
    
    private fun handleDoubleClick() {
        val path = tree.selectionPath ?: return
        val node = path.lastPathComponent as? DefaultMutableTreeNode ?: return
        val data = node.userObject as? TreeNodeData ?: return
        
        if (data.type == TreeNodeType.PORT) {
            // Toggle start/stop on double-click
            if (data.state == ProcessState.STOPPED) {
                handleStartPort()
            } else {
                handleStopPort()
            }
        }
    }
    
    private fun handleStartPort() {
        val selected = getSelectedNodeData() ?: return
        println("🔍 [MCCToolWindow] handleStartPort: ${selected.type}, service=${selected.serviceId}, host=${selected.hostId}, port=${selected.portId}")
        
        when (selected.type) {
            TreeNodeType.PORT -> {
                val svc = service.services.value.find { it.id == selected.serviceId } ?: return
                val host = svc.hosts.find { it.id == selected.hostId } ?: return
                val port = host.compatiblePorts.find { it.id == selected.portId } ?: return
                service.startPort(host, port)
            }
            TreeNodeType.HOST -> {
                val svc = service.services.value.find { it.id == selected.serviceId } ?: return
                val host = svc.hosts.find { it.id == selected.hostId } ?: return
                host.compatiblePorts.forEach { port ->
                    service.startPort(host, port)
                }
            }
            TreeNodeType.SERVICE -> {
                val svc = service.services.value.find { it.id == selected.serviceId } ?: return
                svc.hosts.forEach { host ->
                    host.compatiblePorts.forEach { port ->
                        service.startPort(host, port)
                    }
                }
            }
        }
    }
    
    private fun handleStopPort() {
        val selected = getSelectedNodeData() ?: return
        println("🔍 [MCCToolWindow] handleStopPort: ${selected.type}")
        
        when (selected.type) {
            TreeNodeType.PORT -> {
                val svc = service.services.value.find { it.id == selected.serviceId } ?: return
                val host = svc.hosts.find { it.id == selected.hostId } ?: return
                val port = host.compatiblePorts.find { it.id == selected.portId } ?: return
                service.stopPort(host, port)
            }
            TreeNodeType.HOST -> {
                val svc = service.services.value.find { it.id == selected.serviceId } ?: return
                val host = svc.hosts.find { it.id == selected.hostId } ?: return
                host.compatiblePorts.forEach { port ->
                    service.stopPort(host, port)
                }
            }
            TreeNodeType.SERVICE -> {
                val svc = service.services.value.find { it.id == selected.serviceId } ?: return
                svc.hosts.forEach { host ->
                    host.compatiblePorts.forEach { port ->
                        service.stopPort(host, port)
                    }
                }
            }
        }
    }
    
    private fun handleKillProcess() {
        val selected = getSelectedNodeData() ?: return
        if (selected.type != TreeNodeType.PORT) return
        
        val svc = service.services.value.find { it.id == selected.serviceId } ?: return
        val host = svc.hosts.find { it.id == selected.hostId } ?: return
        val port = host.compatiblePorts.find { it.id == selected.portId } ?: return
        
        val result = Messages.showYesNoDialog(
            project,
            "Kill process on local port ${port.toPort}?\n\nThis will terminate any process using this port.",
            "Kill Process",
            Messages.getWarningIcon()
        )
        
        if (result == Messages.YES) {
            service.killProcessOnPort(port.toPort)
        }
    }
    
    private fun handleViewLogs() {
        val selected = getSelectedNodeData() ?: return
        if (selected.type != TreeNodeType.PORT) return
        
        val svc = service.services.value.find { it.id == selected.serviceId } ?: return
        val host = svc.hosts.find { it.id == selected.hostId } ?: return
        val port = host.compatiblePorts.find { it.id == selected.portId } ?: return
        
        val processId = host.processId(port)
        val logs = service.getLogs(processId)
        
        val message = if (logs.isEmpty()) {
            "No logs available for this port."
        } else {
            logs.takeLast(50).joinToString("\n")
        }
        
        Messages.showMessageDialog(
            project,
            message,
            "Logs: ${port.fromPort}→${port.toPort}",
            Messages.getInformationIcon()
        )
    }
    
    private fun getSelectedNodeData(): TreeNodeData? {
        val path = tree.selectionPath ?: return null
        val node = path.lastPathComponent as? DefaultMutableTreeNode ?: return null
        return node.userObject as? TreeNodeData
    }
    
    // Data class to store node information
    private data class TreeNodeData(
        val type: TreeNodeType,
        val label: String,
        val serviceId: java.util.UUID? = null,
        val hostId: java.util.UUID? = null,
        val portId: java.util.UUID? = null,
        val state: ProcessState = ProcessState.STOPPED
    ) {
        override fun toString(): String = label
    }
    
    private enum class TreeNodeType {
        SERVICE, HOST, PORT
    }
}

