package com.mcc.portforwarder.toolwindow

import com.intellij.openapi.project.Project
import com.intellij.ui.components.JBScrollPane
import com.intellij.ui.treeStructure.Tree
import com.mcc.portforwarder.services.MCCPortForwarderService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
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
        val panel = JPanel()
        panel.layout = BoxLayout(panel, BoxLayout.Y_AXIS)
        
        // Toolbar
        val toolbar = createToolbar()
        panel.add(toolbar)
        
        // Tree
        val scrollPane = JBScrollPane(tree)
        panel.add(scrollPane)
        
        return panel
    }
    
    private fun createToolbar(): JComponent {
        val toolbar = JPanel()
        toolbar.layout = BoxLayout(toolbar, BoxLayout.X_AXIS)
        
        val addServiceButton = JButton("Add Service")
        addServiceButton.addActionListener {
            // TODO: Show add service dialog
        }
        toolbar.add(addServiceButton)
        
        toolbar.add(Box.createHorizontalGlue())
        
        val startAllButton = JButton("Start All")
        startAllButton.addActionListener {
            // TODO: Start all services
        }
        toolbar.add(startAllButton)
        
        val stopAllButton = JButton("Stop All")
        stopAllButton.addActionListener {
            // TODO: Stop all services
        }
        toolbar.add(stopAllButton)
        
        return toolbar
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

