package com.mcc.portforwarder.actions

import com.intellij.icons.AllIcons
import com.intellij.openapi.actionSystem.AnAction
import com.intellij.openapi.actionSystem.AnActionEvent
import com.intellij.openapi.project.DumbAware
import com.mcc.portforwarder.dialogs.AddServiceDialog
import com.mcc.portforwarder.dialogs.SettingsDialog
import com.mcc.portforwarder.services.MCCService

/**
 * Actions для toolbar (правильный способ вместо JButton)
 */

// ==================== Login Action ====================

class LoginAction : AnAction("Login", "Authenticate with MCC", AllIcons.Actions.Execute), DumbAware {
    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val service = MCCService.getInstance(project)
        service.login()
    }
    
    override fun update(e: AnActionEvent) {
        val project = e.project
        if (project == null) {
            e.presentation.isEnabled = false
            return
        }
        
        val service = MCCService.getInstance(project)
        e.presentation.isEnabled = !service.isAuthenticated.value
    }
}

// ==================== Logout Action ====================

class LogoutAction : AnAction("Logout", "Logout from MCC", AllIcons.Actions.Suspend), DumbAware {
    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        val service = MCCService.getInstance(project)
        service.logout()
    }
    
    override fun update(e: AnActionEvent) {
        val project = e.project
        if (project == null) {
            e.presentation.isEnabled = false
            return
        }
        
        val service = MCCService.getInstance(project)
        e.presentation.isEnabled = service.isAuthenticated.value
    }
}

// ==================== Settings Action ====================

class SettingsAction : AnAction("Settings", "Open settings", AllIcons.General.Settings), DumbAware {
    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        SettingsDialog(project).show()
    }
}

// ==================== Add Service Action ====================

class AddServiceAction : AnAction("Add Service", "Add new service", AllIcons.General.Add), DumbAware {
    override fun actionPerformed(e: AnActionEvent) {
        val project = e.project ?: return
        AddServiceDialog(project, parentServiceId = null).show()
    }
}

