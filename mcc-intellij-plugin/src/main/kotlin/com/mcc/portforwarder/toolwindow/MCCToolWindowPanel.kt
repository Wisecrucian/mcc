package com.mcc.portforwarder.toolwindow

import com.intellij.icons.AllIcons
import com.intellij.openapi.Disposable
import com.intellij.openapi.actionSystem.ActionManager
import com.intellij.openapi.actionSystem.DefaultActionGroup
import com.intellij.openapi.project.Project
import com.intellij.openapi.wm.ToolWindowManager
import com.intellij.openapi.wm.ex.ToolWindowManagerListener
import com.intellij.ui.JBSplitter
import com.intellij.ui.components.JBList
import com.intellij.ui.components.JBScrollPane
import com.mcc.portforwarder.actions.*
import com.mcc.portforwarder.dialogs.*
import com.mcc.portforwarder.models.*
import com.mcc.portforwarder.services.MCCService
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collectLatest
import java.awt.BorderLayout
import java.awt.FlowLayout
import java.awt.GridBagConstraints
import java.awt.GridBagLayout
import javax.swing.*
import java.util.UUID

/**
 * Master-Detail Panel для MCC Port Forwarder
 * Левая панель - список сервисов
 * Правая панель - детали выбранного сервиса
 */
class MCCToolWindowPanel(private val project: Project) : JPanel(), Disposable {

    private val service = MCCService.getInstance(project)
    private val coroutineScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    // Master panel (left)
    private val serviceListModel = DefaultListModel<MCCServiceModel>()
    private val serviceList = JBList(serviceListModel)
    
    // Detail panel (right)
    private val detailPanel = JPanel(BorderLayout())
    private val detailContent = JPanel()
    private val detailScroll = JBScrollPane(detailContent)
    
    // Footer
    private val footerLabel = JLabel("Initializing...")
    
    // UI Scaling based on window mode
    private var isCompactMode = false
    private val compactButtonMargin = java.awt.Insets(0, 1, 0, 1)  // Very tight
    private val normalButtonMargin = java.awt.Insets(2, 6, 2, 6)
    private val compactFontSize = 9f  // Smaller font for compact mode
    private val normalFontSize = 12f
    
    // Track selected service ID to restore selection after updates
    private var selectedServiceId: UUID? = null

    init {
        layout = BorderLayout()

        setupToolbar()
        setupMasterDetailLayout()
        setupFooter()
        
        observeState()
        setupWindowModeListener()
    }
    
    private fun setupWindowModeListener() {
        // Check initial mode
        updateCompactMode()
        
        // Listen for mode changes
        project.messageBus.connect(this).subscribe(
            ToolWindowManagerListener.TOPIC,
            object : ToolWindowManagerListener {
                override fun stateChanged(toolWindowManager: com.intellij.openapi.wm.ToolWindowManager) {
                    updateCompactMode()
                }
            }
        )
    }
    
    private fun updateCompactMode() {
        val toolWindowManager = ToolWindowManager.getInstance(project)
        val toolWindow = toolWindowManager.getToolWindow("MCCPortForwarder")
        
        val newCompactMode = toolWindow?.type == com.intellij.openapi.wm.ToolWindowType.WINDOWED ||
                             toolWindow?.type == com.intellij.openapi.wm.ToolWindowType.FLOATING
        
        if (newCompactMode != isCompactMode) {
            isCompactMode = newCompactMode
            SwingUtilities.invokeLater {
                updateDetailPanel() // Refresh UI with new sizing
            }
        }
    }

    private fun setupToolbar() {
        val actionGroup = DefaultActionGroup()
        actionGroup.add(LoginAction())
        actionGroup.add(LogoutAction())
        actionGroup.addSeparator()
        actionGroup.add(SettingsAction())
        actionGroup.add(AddServiceAction())

        val toolbar = ActionManager.getInstance()
            .createActionToolbar("MCCToolbar", actionGroup, true)
        toolbar.targetComponent = this
        add(toolbar.component, BorderLayout.NORTH)
    }

    private fun setupMasterDetailLayout() {
        // Configure service list
        serviceList.cellRenderer = ServiceListCellRenderer()
        serviceList.addListSelectionListener {
            if (!it.valueIsAdjusting) {
                val selected = serviceList.selectedValue
                selectedServiceId = selected?.id
                updateDetailPanel()
            }
        }

        // Master panel (left side)
        val masterPanel = JPanel(BorderLayout())
        masterPanel.add(JBScrollPane(serviceList), BorderLayout.CENTER)
        
        val addServiceButton = JButton("+ Add Service")
        addServiceButton.addActionListener {
            AddServiceDialog(project).show()
        }
        masterPanel.add(addServiceButton, BorderLayout.SOUTH)

        // Detail panel (right side)
        detailPanel.add(detailScroll, BorderLayout.CENTER)
        updateDetailPanel() // Show empty state

        // Splitter
        val splitter = JBSplitter(false, 0.25f)
        splitter.firstComponent = masterPanel
        splitter.secondComponent = detailPanel

        add(splitter, BorderLayout.CENTER)
    }

    private fun setupFooter() {
        val footerPanel = JPanel(BorderLayout())
        
        // Auth buttons
        val authPanel = JPanel(FlowLayout(FlowLayout.LEFT))
        val loginButton = JButton("Login")
        val logoutButton = JButton("Logout")

        loginButton.addActionListener {
            loginButton.isEnabled = false
            logoutButton.isEnabled = false
            service.login()
            coroutineScope.launch {
                delay(1000)
                loginButton.isEnabled = true
                logoutButton.isEnabled = true
            }
        }

        logoutButton.addActionListener {
            loginButton.isEnabled = false
            logoutButton.isEnabled = false
            service.logout()
            coroutineScope.launch {
                delay(1000)
                loginButton.isEnabled = true
                logoutButton.isEnabled = true
            }
        }

        authPanel.add(loginButton)
        authPanel.add(logoutButton)
        authPanel.add(footerLabel)
        
        footerPanel.add(authPanel, BorderLayout.CENTER)
        add(footerPanel, BorderLayout.SOUTH)
    }

    private fun observeState() {
        coroutineScope.launch {
            service.services.collectLatest { services ->
                SwingUtilities.invokeLater {
                    println("🔄 MCCToolWindowPanel: Services updated, count=${services.size}")
                    val selectedService = serviceList.selectedValue
                    val selectedId = selectedService?.id
                    
                    // Update the list with fresh service objects
                    updateServiceList(services)
                    
                    // Restore selection by finding the index in the flat list
                    if (selectedId != null) {
                        // Find index in the flat list model (not in services hierarchy)
                        val flatIndex = (0 until serviceListModel.size()).firstOrNull { i ->
                            serviceListModel.getElementAt(i).id == selectedId
                        }
                        if (flatIndex != null) {
                            serviceList.selectedIndex = flatIndex
                            val freshService = findServiceById(services, selectedId)
                            println("🔍 MCCToolWindowPanel: Fresh service found, hosts=${freshService?.hosts?.size ?: 0}")
                        } else {
                            // Service was deleted
                            selectedServiceId = null
                        }
                    }
                    
                    // Always update detail panel to ensure it shows fresh data
                    updateDetailPanel()
                }
            }
        }

        coroutineScope.launch {
            service.isAuthenticated.collectLatest { _ ->
                SwingUtilities.invokeLater {
                    updateFooter()
                }
            }
        }

        coroutineScope.launch {
            service.processStates.collectLatest {
                SwingUtilities.invokeLater {
                    updateFooter()
                    updateDetailPanel() // Refresh to show updated states
                }
            }
        }
    }

    private fun updateServiceList(services: List<MCCServiceModel>) {
        serviceListModel.clear()
        
        fun addServicesRecursively(servicesList: List<MCCServiceModel>, indent: Int = 0) {
            servicesList.forEach { svc ->
                serviceListModel.addElement(svc)
                if (svc.childServices.isNotEmpty()) {
                    addServicesRecursively(svc.childServices, indent + 1)
                }
            }
        }
        
        addServicesRecursively(services)
    }

    private fun createAdaptiveButton(text: String, icon: String? = null, tooltip: String? = null, action: () -> Unit): JButton {
        val displayText = if (isCompactMode && icon != null) icon else text
        return JButton(displayText).apply {
            margin = if (isCompactMode) compactButtonMargin else normalButtonMargin
            font = font.deriveFont(if (isCompactMode) compactFontSize else normalFontSize)
            toolTipText = tooltip ?: text
            addActionListener { action() }
        }
    }
    
    private fun updateDetailPanel() {
        detailContent.removeAll()
        
        // Get FRESH service object from service.services, not from old list selection
        val selectedService = if (selectedServiceId != null) {
            findServiceById(service.services.value, selectedServiceId!!)
        } else {
            null
        }
        
        println("📋 updateDetailPanel: selectedServiceId=$selectedServiceId, service=${ selectedService?.name}, hosts=${selectedService?.hosts?.size ?: 0}")
        
        if (selectedService == null) {
            // Empty state
            detailContent.layout = BorderLayout()
            detailContent.add(JLabel("Select a service to view details", SwingConstants.CENTER), BorderLayout.CENTER)
        } else {
            // Show service details
            detailContent.layout = BoxLayout(detailContent, BoxLayout.Y_AXIS)
            
            // Service header
            val headerPanel = JPanel(FlowLayout(FlowLayout.LEFT))
            val headerLabel = JLabel("📁 ${selectedService.name}", AllIcons.Nodes.Folder, SwingConstants.LEFT)
            if (isCompactMode) {
                headerLabel.font = headerLabel.font.deriveFont(12f)
            }
            headerPanel.add(headerLabel)
            detailContent.add(headerPanel)
            
            detailContent.add(JSeparator())
            
            // Service actions
            val serviceActionsPanel = JPanel(FlowLayout(FlowLayout.LEFT, if (isCompactMode) 2 else 5, if (isCompactMode) 2 else 5))
            serviceActionsPanel.add(createAdaptiveButton("Edit Service", "✏️", "Edit Service") {
                AddServiceDialog(project, editingService = selectedService).show()
            })
            serviceActionsPanel.add(createAdaptiveButton("Add Child Service", "➕", "Add Child Service") {
                AddServiceDialog(project, parentServiceId = selectedService.id).show()
            })
            serviceActionsPanel.add(createAdaptiveButton("Add Host", "🖥️", "Add Host") {
                AddHostDialog(project, serviceId = selectedService.id).show()
            })
            serviceActionsPanel.add(createAdaptiveButton("Start All", "▶️", "Start All") {
                service.startService(selectedService.id)
            })
            serviceActionsPanel.add(createAdaptiveButton("Stop All", "⏹️", "Stop All") {
                service.stopService(selectedService.id)
            })
            serviceActionsPanel.add(createAdaptiveButton("View Logs", "📋", "View Logs") {
                ServiceLogsDialog(project, selectedService, "Logs: ${selectedService.name}").show()
            })
            serviceActionsPanel.add(createAdaptiveButton("Delete Service", "🗑️", "Delete Service") {
                val result = JOptionPane.showConfirmDialog(
                    this,
                    "Delete service '${selectedService.name}'?",
                    "Confirm",
                    JOptionPane.YES_NO_OPTION
                )
                if (result == JOptionPane.YES_OPTION) {
                    service.deleteService(selectedService.id)
                }
            })
            detailContent.add(serviceActionsPanel)
            
            detailContent.add(Box.createVerticalStrut(if (isCompactMode) 5 else 10))
            
            // Hosts
            val hostsLabel = JLabel("Hosts (${selectedService.hosts.size}):")
            hostsLabel.font = hostsLabel.font.deriveFont(if (isCompactMode) 12f else 14f)
            detailContent.add(hostsLabel)
            
            if (selectedService.hosts.isEmpty()) {
                detailContent.add(JLabel("  No hosts configured"))
            } else {
                selectedService.hosts.forEach { host ->
                    detailContent.add(createHostPanel(selectedService, host))
                }
            }
            
            // Child services
            if (selectedService.childServices.isNotEmpty()) {
                detailContent.add(Box.createVerticalStrut(10))
                val childLabel = JLabel("Child Services (${selectedService.childServices.size}):")
                childLabel.font = childLabel.font.deriveFont(14f)
                detailContent.add(childLabel)
                
                selectedService.childServices.forEach { child ->
                    val childPanel = JPanel(FlowLayout(FlowLayout.LEFT))
                    childPanel.add(JLabel("  📁 ${child.name}"))
                    detailContent.add(childPanel)
                }
            }
        }
        
        detailContent.revalidate()
        detailContent.repaint()
    }

    private fun createHostPanel(svc: MCCServiceModel, host: Host): JPanel {
        val hostPanel = JPanel()
        hostPanel.layout = BoxLayout(hostPanel, BoxLayout.Y_AXIS)
        hostPanel.border = if (isCompactMode) {
            BorderFactory.createCompoundBorder(
                BorderFactory.createLineBorder(java.awt.Color.LIGHT_GRAY, 1),
                BorderFactory.createEmptyBorder(2, 4, 2, 4)
            )
        } else {
            BorderFactory.createTitledBorder("🖥️ ${host.name}")
        }
        
        // Host info
        val infoPanel = JPanel(FlowLayout(FlowLayout.LEFT, if (isCompactMode) 2 else 5, if (isCompactMode) 1 else 5))
        val hostNameLabel = JLabel(if (isCompactMode) "🖥️ ${host.name}" else "Template: ${host.hostnameTemplate}")
        hostNameLabel.font = hostNameLabel.font.deriveFont(if (isCompactMode) 11f else 12f)
        infoPanel.add(hostNameLabel)
        if (!isCompactMode) {
            infoPanel.add(JLabel(" | Remote Port: ${host.remotePort}"))
        }
        hostPanel.add(infoPanel)
        
        // Locations (ports)
        host.locations.forEach { location ->
            val processId = host.processId(location)
            val state = service.getProcessState(processId)
            
            val locationPanel = JPanel(FlowLayout(FlowLayout.LEFT))
            
            // Status icon
            val statusIcon = when (state) {
                ProcessState.RUNNING -> AllIcons.RunConfigurations.TestPassed
                ProcessState.ERROR -> AllIcons.RunConfigurations.TestError
                ProcessState.PORT_IN_USE -> AllIcons.General.Warning
                ProcessState.RESTARTING -> AllIcons.Process.ProgressResume
                ProcessState.STOPPED -> AllIcons.RunConfigurations.TestIgnored
            }
            
            val locationLabel = JLabel("    ${location.datacenter}: ${host.remotePort} → ${location.localPort} [${state.displayName}]", statusIcon, SwingConstants.LEFT)
            locationLabel.font = locationLabel.font.deriveFont(if (isCompactMode) 10f else 12f)
            locationPanel.add(locationLabel)
            
            // Port actions
            val toggleText = if (state.isActive) "Stop" else "Start"
            val toggleIcon = if (state.isActive) "⏹️" else "▶️"
            locationPanel.add(createAdaptiveButton("$toggleIcon $toggleText", toggleIcon, toggleText) {
                service.toggleLocation(host, location)
            })
            
            locationPanel.add(createAdaptiveButton("📋 Logs", "📋", "View Logs") {
                val title = "Logs: ${host.name} - ${location.datacenter}"
                LogViewerDialog(project, processId, title).show()
            })
            
            if (state == ProcessState.PORT_IN_USE) {
                locationPanel.add(createAdaptiveButton("💀 Kill", "💀", "Kill Process on Port") {
                    killProcessOnPort(location.localPort)
                })
            }
            
            hostPanel.add(locationPanel)
        }
        
        // Host actions
        val hostActionsPanel = JPanel(FlowLayout(FlowLayout.LEFT, if (isCompactMode) 2 else 5, if (isCompactMode) 2 else 5))
        hostActionsPanel.add(createAdaptiveButton("Edit Host", "✏️", "Edit Host") {
            AddHostDialog(project, serviceId = svc.id, editingHost = host).show()
        })
        hostActionsPanel.add(createAdaptiveButton("Start All", "▶️", "Start All") {
            service.startHost(host)
        })
        hostActionsPanel.add(createAdaptiveButton("Stop All", "⏹️", "Stop All") {
            service.stopHost(host)
        })
        hostActionsPanel.add(createAdaptiveButton("View Logs", "📋", "View Logs") {
            HostLogsDialog(project, host, "Logs: ${host.name}").show()
        })
        hostActionsPanel.add(createAdaptiveButton("Delete Host", "🗑️", "Delete Host") {
            val result = JOptionPane.showConfirmDialog(
                this,
                "Delete host '${host.name}'?",
                "Confirm",
                JOptionPane.YES_NO_OPTION
            )
            if (result == JOptionPane.YES_OPTION) {
                service.deleteHost(host.id)
            }
        })
        hostPanel.add(hostActionsPanel)
        
        return hostPanel
    }

    private fun killProcessOnPort(port: Int) {
        val result = JOptionPane.showConfirmDialog(
            this,
            "Kill process on port $port?",
            "Confirm Kill",
            JOptionPane.YES_NO_OPTION,
            JOptionPane.WARNING_MESSAGE
        )
        
        if (result == JOptionPane.YES_OPTION) {
            coroutineScope.launch(Dispatchers.IO) {
                try {
                    val lsofProcess = ProcessBuilder("lsof", "-ti", ":$port").start()
                    val pid = lsofProcess.inputStream.bufferedReader().readText().trim()
                    lsofProcess.waitFor()
                    
                    if (pid.isNotEmpty()) {
                        val killProcess = ProcessBuilder("kill", "-9", pid).start()
                        killProcess.waitFor()
                        
                        withContext(Dispatchers.Main) {
                            JOptionPane.showMessageDialog(
                                this@MCCToolWindowPanel,
                                "Process killed successfully",
                                "Success",
                                JOptionPane.INFORMATION_MESSAGE
                            )
                        }
                    } else {
                        withContext(Dispatchers.Main) {
                            JOptionPane.showMessageDialog(
                                this@MCCToolWindowPanel,
                                "No process found on port $port",
                                "Info",
                                JOptionPane.INFORMATION_MESSAGE
                            )
                        }
                    }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        JOptionPane.showMessageDialog(
                            this@MCCToolWindowPanel,
                            "Failed to kill process: ${e.message}",
                            "Error",
                            JOptionPane.ERROR_MESSAGE
                        )
                    }
                }
            }
        }
    }

    private fun updateFooter() {
        val authenticated = if (service.isAuthenticated.value) "✅ Authenticated" else "❌ Not authenticated"
        val connections = service.getActiveConnectionCount()
        footerLabel.text = "$authenticated | Active connections: $connections"
    }
    
    /**
     * Find service by ID in the service hierarchy (recursively)
     */
    private fun findServiceById(services: List<MCCServiceModel>, id: UUID): MCCServiceModel? {
        services.forEach { svc ->
            if (svc.id == id) return svc
            val found = findServiceById(svc.childServices, id)
            if (found != null) return found
        }
        return null
    }

    /**
     * Custom cell renderer for service list
     */
    private inner class ServiceListCellRenderer : DefaultListCellRenderer() {
        override fun getListCellRendererComponent(
            list: JList<*>?,
            value: Any?,
            index: Int,
            isSelected: Boolean,
            cellHasFocus: Boolean
        ): java.awt.Component {
            super.getListCellRendererComponent(list, value, index, isSelected, cellHasFocus)
            
            val svc = value as? MCCServiceModel
            if (svc != null) {
                icon = AllIcons.Nodes.Folder
                text = "${svc.name} (${svc.totalHostCount} hosts)"
            }
            
            return this
        }
    }

    override fun dispose() {
        coroutineScope.cancel()
    }
}
