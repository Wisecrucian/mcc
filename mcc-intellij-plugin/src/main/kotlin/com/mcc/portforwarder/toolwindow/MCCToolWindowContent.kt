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
import com.mcc.portforwarder.services.MCCSettings
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
        
        // Add Service button
        val addServiceButton = JButton("➕ Add Service")
        addServiceButton.toolTipText = "Add new service"
        addServiceButton.addActionListener {
            showAddServiceDialog()
        }
        toolbar.add(addServiceButton)
        
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
    
    
    
    
    private fun showSettings() {
        val settingsService = MCCSettingsService.getInstance()
        val settings = settingsService.getSettings()
        
        // Create settings panel
        val panel = JPanel()
        panel.layout = BoxLayout(panel, BoxLayout.Y_AXIS)
        panel.border = BorderFactory.createEmptyBorder(10, 10, 10, 10)
        
        // Command
        panel.add(JLabel("Command:"))
        val commandField = JTextField(settings.command, 30)
        panel.add(commandField)
        panel.add(Box.createVerticalStrut(10))
        
        // Login Command
        panel.add(JLabel("Login Command:"))
        val loginCommandField = JTextField(settings.loginCommand, 30)
        panel.add(loginCommandField)
        panel.add(Box.createVerticalStrut(10))
        
        // Logout Command
        panel.add(JLabel("Logout Command:"))
        val logoutCommandField = JTextField(settings.logoutCommand, 30)
        panel.add(logoutCommandField)
        panel.add(Box.createVerticalStrut(10))
        
        // Retry Enabled
        val retryCheckbox = JCheckBox("Enable Retry", settings.retryEnabled)
        panel.add(retryCheckbox)
        panel.add(Box.createVerticalStrut(10))
        
        // Retry Attempts
        panel.add(JLabel("Retry Attempts:"))
        val retryAttemptsField = JTextField(settings.retryAttempts.toString(), 5)
        panel.add(retryAttemptsField)
        panel.add(Box.createVerticalStrut(10))
        
        // Retry Delay
        panel.add(JLabel("Retry Delay (seconds):"))
        val retryDelayField = JTextField(settings.retryDelay.toString(), 5)
        panel.add(retryDelayField)
        panel.add(Box.createVerticalStrut(10))
        
        // Datacenters
        panel.add(JLabel("Datacenters (comma-separated):"))
        val datacentersField = JTextField(settings.datacenters.joinToString(", "), 30)
        panel.add(datacentersField)
        
        // Show dialog using DialogWrapper for custom panel
        val dialog = object : com.intellij.openapi.ui.DialogWrapper(project) {
            init {
                title = "Settings"
                init()
            }
            
            override fun createCenterPanel() = panel
        }
        
        val result = if (dialog.showAndGet()) 0 else 1
        
        if (result == 0) { // 0 = Save button
            try {
                val newSettings = MCCSettings(
                    command = commandField.text,
                    loginCommand = loginCommandField.text,
                    logoutCommand = logoutCommandField.text,
                    retryEnabled = retryCheckbox.isSelected,
                    retryAttempts = retryAttemptsField.text.toIntOrNull() ?: settings.retryAttempts,
                    retryDelay = retryDelayField.text.toIntOrNull() ?: settings.retryDelay,
                    datacenters = datacentersField.text.split(",").map { it.trim() }.filter { it.isNotEmpty() }
                )
                
                settingsService.updateSettings(newSettings)
                Messages.showInfoMessage(project, "Settings saved successfully!", "Settings")
            } catch (e: Exception) {
                Messages.showErrorDialog(project, "Failed to save settings: ${e.message}", "Error")
            }
        }
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
        
        val editItem = JMenuItem("Edit")
        editItem.addActionListener { handleEditService() }
        popupMenu.add(editItem)
        
        val deleteItem = JMenuItem("Delete")
        deleteItem.addActionListener { handleDeleteService() }
        popupMenu.add(deleteItem)
        
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
                            startItem.isVisible = true
                            stopItem.isVisible = true
                            editItem.isVisible = false
                            deleteItem.isVisible = false
                            killItem.isVisible = true
                            logsItem.isVisible = true
                            
                            startItem.isEnabled = data.state != ProcessState.READY
                            stopItem.isEnabled = data.state != ProcessState.STOPPED
                        }
                        TreeNodeType.HOST -> {
                            startItem.isVisible = true
                            stopItem.isVisible = true
                            editItem.isVisible = false
                            deleteItem.isVisible = false
                            killItem.isVisible = false
                            logsItem.isVisible = false
                            
                            startItem.text = "Start All Ports"
                            stopItem.text = "Stop All Ports"
                        }
                        TreeNodeType.SERVICE -> {
                            startItem.isVisible = true
                            stopItem.isVisible = true
                            editItem.isVisible = true
                            deleteItem.isVisible = true
                            killItem.isVisible = false
                            logsItem.isVisible = false
                            
                            startItem.text = "Start Service"
                            stopItem.text = "Stop Service"
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
    
    private fun showAddServiceDialog() {
        val panel = JPanel()
        panel.layout = BoxLayout(panel, BoxLayout.Y_AXIS)
        panel.border = BorderFactory.createEmptyBorder(10, 10, 10, 10)
        
        panel.add(JLabel("Service Name:"))
        val nameField = JTextField(30)
        panel.add(nameField)
        
        val dialog = object : com.intellij.openapi.ui.DialogWrapper(project) {
            init {
                title = "Add Service"
                init()
            }
            
            override fun createCenterPanel() = panel
        }
        
        if (dialog.showAndGet()) {
            val name = nameField.text.trim()
            if (name.isEmpty()) {
                Messages.showErrorDialog(project, "Service name cannot be empty", "Error")
                return
            }
            
            val newService = com.mcc.portforwarder.models.Service(name = name)
            service.addService(newService)
            
            Messages.showInfoMessage(
                project,
                "Service '${name}' created successfully!\n\nYou can now add hosts to this service.",
                "Service Created"
            )
        }
    }
    
    private fun handleEditService() {
        val selected = getSelectedNodeData() ?: return
        if (selected.type != TreeNodeType.SERVICE) return
        
        val svc = service.services.value.find { it.id == selected.serviceId } ?: return
        
        val panel = JPanel()
        panel.layout = BoxLayout(panel, BoxLayout.Y_AXIS)
        panel.border = BorderFactory.createEmptyBorder(10, 10, 10, 10)
        
        panel.add(JLabel("Service Name:"))
        val nameField = JTextField(svc.name, 30)
        panel.add(nameField)
        
        val dialog = object : com.intellij.openapi.ui.DialogWrapper(project) {
            init {
                title = "Edit Service"
                init()
            }
            
            override fun createCenterPanel() = panel
        }
        
        if (dialog.showAndGet()) {
            val newName = nameField.text.trim()
            if (newName.isEmpty()) {
                Messages.showErrorDialog(project, "Service name cannot be empty", "Error")
                return
            }
            
            val updatedService = svc.copy(name = newName)
            service.updateService(updatedService)
            
            Messages.showInfoMessage(project, "Service updated successfully!", "Success")
        }
    }
    
    private fun handleDeleteService() {
        val selected = getSelectedNodeData() ?: return
        if (selected.type != TreeNodeType.SERVICE) return
        
        val svc = service.services.value.find { it.id == selected.serviceId } ?: return
        
        val result = Messages.showYesNoDialog(
            project,
            "Delete service '${svc.name}'?\n\nThis will stop all running ports and remove the service.",
            "Delete Service",
            Messages.getWarningIcon()
        )
        
        if (result == Messages.YES) {
            // Stop all ports first
            svc.hosts.forEach { host ->
                host.compatiblePorts.forEach { port ->
                    service.stopPort(host, port)
                }
            }
            
            service.deleteService(svc)
            Messages.showInfoMessage(project, "Service '${svc.name}' deleted successfully!", "Success")
        }
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

