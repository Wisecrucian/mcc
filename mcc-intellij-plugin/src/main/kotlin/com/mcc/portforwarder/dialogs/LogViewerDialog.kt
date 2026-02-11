package com.mcc.portforwarder.dialogs

import com.intellij.openapi.project.Project
import com.intellij.openapi.ui.DialogWrapper
import com.intellij.ui.components.JBScrollPane
import com.intellij.ui.components.JBTextArea
import com.mcc.portforwarder.models.Host
import com.mcc.portforwarder.models.MCCServiceModel
import com.mcc.portforwarder.services.MCCService
import java.awt.Dimension
import java.util.*
import javax.swing.JComponent

/**
 * Log Viewer Dialog для просмотра логов процесса
 */
class LogViewerDialog(
    private val project: Project,
    private val processId: UUID,
    title: String
) : DialogWrapper(project) {
    
    private val service = MCCService.getInstance(project)
    
    init {
        this.title = title
        init()
    }
    
    override fun createCenterPanel(): JComponent {
        val logs = service.getProcessLogs(processId).joinToString("\n")
        val textArea = JBTextArea(logs)
        textArea.isEditable = false
        textArea.rows = 20
        textArea.columns = 80
        
        val scrollPane = JBScrollPane(textArea)
        scrollPane.preferredSize = Dimension(800, 400)
        
        return scrollPane
    }
}

/**
 * Aggregated Log Viewer для сервиса - показывает логи всех портов
 */
class ServiceLogsDialog(
    private val project: Project,
    private val mccService: MCCServiceModel,
    title: String
) : DialogWrapper(project) {
    
    private val service = MCCService.getInstance(project)
    
    init {
        this.title = title
        init()
    }
    
    override fun createCenterPanel(): JComponent {
        val allLogs = StringBuilder()
        
        // Collect logs from all hosts and locations
        for (host in mccService.allHosts) {
            allLogs.append("═══════════════════════════════════════\n")
            allLogs.append("HOST: ${host.name}\n")
            allLogs.append("═══════════════════════════════════════\n\n")
            
            for (location in host.locations) {
                val processId = host.processId(location)
                val logs = service.getProcessLogs(processId)
                
                if (logs.isNotEmpty()) {
                    allLogs.append("─── ${location.datacenter} (${host.remotePort} → ${location.localPort}) ───\n")
                    logs.forEach { log ->
                        allLogs.append("$log\n")
                    }
                    allLogs.append("\n")
                }
            }
        }
        
        if (allLogs.isEmpty()) {
            allLogs.append("No logs available for this service")
        }
        
        val textArea = JBTextArea(allLogs.toString())
        textArea.isEditable = false
        textArea.rows = 25
        textArea.columns = 100
        
        val scrollPane = JBScrollPane(textArea)
        scrollPane.preferredSize = Dimension(900, 500)
        
        return scrollPane
    }
}

/**
 * Aggregated Log Viewer для хоста - показывает логи всех его портов
 */
class HostLogsDialog(
    private val project: Project,
    private val host: Host,
    title: String
) : DialogWrapper(project) {
    
    private val service = MCCService.getInstance(project)
    
    init {
        this.title = title
        init()
    }
    
    override fun createCenterPanel(): JComponent {
        val allLogs = StringBuilder()
        
        allLogs.append("═══════════════════════════════════════\n")
        allLogs.append("HOST: ${host.name}\n")
        allLogs.append("Template: ${host.hostnameTemplate}\n")
        allLogs.append("Remote Port: ${host.remotePort}\n")
        allLogs.append("═══════════════════════════════════════\n\n")
        
        for (location in host.locations) {
            val processId = host.processId(location)
            val logs = service.getProcessLogs(processId)
            val state = service.getProcessState(processId)
            
            allLogs.append("─── ${location.datacenter} → localhost:${location.localPort} [${state.displayName}] ───\n")
            
            if (logs.isNotEmpty()) {
                logs.forEach { log ->
                    allLogs.append("$log\n")
                }
            } else {
                allLogs.append("(no logs)\n")
            }
            allLogs.append("\n")
        }
        
        val textArea = JBTextArea(allLogs.toString())
        textArea.isEditable = false
        textArea.rows = 25
        textArea.columns = 100
        
        val scrollPane = JBScrollPane(textArea)
        scrollPane.preferredSize = Dimension(900, 500)
        
        return scrollPane
    }
}

