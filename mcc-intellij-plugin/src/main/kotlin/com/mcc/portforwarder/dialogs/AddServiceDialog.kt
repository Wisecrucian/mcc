package com.mcc.portforwarder.dialogs

import com.intellij.openapi.project.Project
import com.intellij.openapi.ui.DialogWrapper
import com.intellij.openapi.ui.ValidationInfo
import com.intellij.ui.dsl.builder.panel
import com.mcc.portforwarder.models.MCCServiceModel
import com.mcc.portforwarder.services.MCCService
import java.util.*
import javax.swing.JComponent
import javax.swing.JTextField

/**
 * DialogWrapper для добавления/редактирования сервиса
 */
class AddServiceDialog(
    private val project: Project,
    private val parentServiceId: UUID? = null,
    private val editingService: MCCServiceModel? = null
) : DialogWrapper(project) {
    
    private val serviceNameField: JTextField = JTextField(editingService?.name ?: "")
    
    init {
        title = if (editingService != null) "Edit Service" else "Add Service"
        init()
    }
    
    override fun createCenterPanel(): JComponent {
        return panel {
            row("Service Name:") {
                cell(serviceNameField)
                    .focused()
                    .comment("Enter a unique name for this service")
            }
        }
    }
    
    override fun doValidate(): ValidationInfo? {
        if (serviceNameField.text.isBlank()) {
            return ValidationInfo("Service name cannot be empty", serviceNameField)
        }
        return null
    }
    
    override fun doOKAction() {
        val service = MCCService.getInstance(project)
        
        if (editingService != null) {
            // Update existing service
            editingService.name = serviceNameField.text
            service.updateService(editingService)
        } else {
            // Create new service
            val newService = MCCServiceModel(name = serviceNameField.text)
            
            if (parentServiceId != null) {
                // Add as child service
                val parent = service.findService(parentServiceId)
                if (parent != null) {
                    parent.childServices.add(newService)
                    service.updateService(parent)
                }
            } else {
                // Add as top-level service
                service.addService(newService)
            }
        }
        
        super.doOKAction()
    }
}
