//
//  SettingsView.swift
//  MCCPortForwarder
//

import SwiftUI

struct SettingsView: View {
    
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var command: String = ""
    @State private var loginCommand: String = ""
    @State private var logoutCommand: String = ""
    @State private var retryEnabled: Bool = true
    @State private var retryAttempts: String = "3"
    @State private var retryDelay: String = "5"
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    // Port Forward Command
                    settingsSection(
                        title: "Port Forward Command",
                        description: "Command to forward ports.\nFormat: {command} hostname:portfrom -p portto"
                    ) {
                        TextField("e.g., /usr/local/bin/mcc tp-port-forward", text: $command)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 12, design: .monospaced))
                        
                        Text("Example: \(command) db.example.com:5432 -p 5432")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(4)
                    }
                    
                    // Login/Logout Commands
                    settingsSection(
                        title: "Authentication Commands",
                        description: "Commands for login and logout operations"
                    ) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Login Command")
                                .font(.system(size: 11, weight: .medium))
                            TextField("e.g., /usr/local/bin/mcc login", text: $loginCommand)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                            
                            Text("Logout Command")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.top, 4)
                            TextField("e.g., /usr/local/bin/mcc logout", text: $logoutCommand)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12, design: .monospaced))
                        }
                    }
                    
                    // Retry Settings
                    settingsSection(
                        title: "Auto-Retry Connection",
                        description: "Automatically retry failed connections"
                    ) {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Enable Auto-Retry", isOn: $retryEnabled)
                                .toggleStyle(.switch)
                            
                            if retryEnabled {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Max Attempts")
                                            .font(.system(size: 11, weight: .medium))
                                        TextField("3", text: $retryAttempts)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 60)
                                            .multilineTextAlignment(.center)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Delay (seconds)")
                                            .font(.system(size: 11, weight: .medium))
                                        TextField("5", text: $retryDelay)
                                            .textFieldStyle(.roundedBorder)
                                            .frame(width: 60)
                                            .multilineTextAlignment(.center)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Text("Will retry up to \(retryAttempts) times with \(retryDelay)s delay between attempts")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.blue.opacity(0.08))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
                .padding(20)
            }
            
            Divider()
            
            // Footer buttons
            VStack(spacing: 8) {
                // App logs button
                Button(action: {
                    // Close settings first, then show logs
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.showAppLogs()
                    }
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("View Application Logs")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                
                HStack(spacing: 12) {
                    Button("Reset All to Defaults") {
                        viewModel.settingsService.resetAll()
                        loadSettings()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        saveSettings()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isValid)
                }
            }
            .padding(20)
        }
        .frame(width: 600, height: 650)
        .onAppear {
            loadSettings()
        }
    }
    
    // MARK: - Helper Views
    
    private func settingsSection<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            
            content()
        }
        .padding(14)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // MARK: - Validation
    
    private var isValid: Bool {
        if command.isEmpty { return false }
        if loginCommand.isEmpty { return false }
        if logoutCommand.isEmpty { return false }
        
        if retryEnabled {
            guard let attempts = Int(retryAttempts), attempts > 0, attempts <= 20 else {
                return false
            }
            guard let delay = Int(retryDelay), delay > 0, delay <= 60 else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        let service = viewModel.settingsService
        command = service.getCommand()
        loginCommand = service.getLoginCommand()
        logoutCommand = service.getLogoutCommand()
        retryEnabled = service.isRetryEnabled()
        retryAttempts = String(service.getRetryAttempts())
        retryDelay = String(service.getRetryDelay())
    }
    
    private func saveSettings() {
        let service = viewModel.settingsService
        service.saveCommand(command)
        service.saveLoginCommand(loginCommand)
        service.saveLogoutCommand(logoutCommand)
        service.setRetryEnabled(retryEnabled)
        
        if let attempts = Int(retryAttempts) {
            service.saveRetryAttempts(attempts)
        }
        if let delay = Int(retryDelay) {
            service.saveRetryDelay(delay)
        }
    }
}

