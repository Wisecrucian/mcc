//
//  SettingsService.swift
//  MCCPortForwarder
//

import Foundation
import Combine

final class SettingsService: ObservableObject {
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private let commandKey = "com.mcc.portforwarder.command"
    private let loginCommandKey = "com.mcc.portforwarder.loginCommand"
    private let logoutCommandKey = "com.mcc.portforwarder.logoutCommand"
    private let retryEnabledKey = "com.mcc.portforwarder.retryEnabled"
    private let retryAttemptsKey = "com.mcc.portforwarder.retryAttempts"
    private let retryDelayKey = "com.mcc.portforwarder.retryDelay"
    private let datacentersKey = "com.mcc.portforwarder.datacenters"
    
    // Defaults
    private let defaultCommand = "/usr/local/bin/mcc tp-port-forward"
    private let defaultLoginCommand = "/usr/local/bin/mcc login"
    private let defaultLogoutCommand = "/usr/local/bin/mcc logout"
    private let defaultRetryAttempts = 3
    private let defaultRetryDelay = 5 // seconds
    
    // Published properties
    @Published var datacenters: [String] = []
    
    init() {
        loadDatacenters()
    }
    
    // MARK: - Command
    
    func getCommand() -> String {
        defaults.string(forKey: commandKey) ?? defaultCommand
    }
    
    func saveCommand(_ command: String) {
        defaults.set(command, forKey: commandKey)
    }
    
    func resetCommand() {
        defaults.removeObject(forKey: commandKey)
    }
    
    // MARK: - Login/Logout Commands
    
    func getLoginCommand() -> String {
        defaults.string(forKey: loginCommandKey) ?? defaultLoginCommand
    }
    
    func saveLoginCommand(_ command: String) {
        defaults.set(command, forKey: loginCommandKey)
    }
    
    func getLogoutCommand() -> String {
        defaults.string(forKey: logoutCommandKey) ?? defaultLogoutCommand
    }
    
    func saveLogoutCommand(_ command: String) {
        defaults.set(command, forKey: logoutCommandKey)
    }
    
    // MARK: - Retry Settings
    
    func isRetryEnabled() -> Bool {
        // Default to true if not set
        if defaults.object(forKey: retryEnabledKey) == nil {
            return true
        }
        return defaults.bool(forKey: retryEnabledKey)
    }
    
    func setRetryEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: retryEnabledKey)
    }
    
    func getRetryAttempts() -> Int {
        let attempts = defaults.integer(forKey: retryAttemptsKey)
        return attempts > 0 ? attempts : defaultRetryAttempts
    }
    
    func saveRetryAttempts(_ attempts: Int) {
        defaults.set(attempts, forKey: retryAttemptsKey)
    }
    
    func getRetryDelay() -> Int {
        let delay = defaults.integer(forKey: retryDelayKey)
        return delay > 0 ? delay : defaultRetryDelay
    }
    
    func saveRetryDelay(_ delay: Int) {
        defaults.set(delay, forKey: retryDelayKey)
    }
    
    // MARK: - Datacenters Management
    
    private func loadDatacenters() {
        if let saved = defaults.stringArray(forKey: datacentersKey) {
            datacenters = saved
        } else {
            // Default datacenters on first launch
            datacenters = []
        }
    }
    
    private func saveDatacenters() {
        defaults.set(datacenters, forKey: datacentersKey)
    }
    
    func addDatacenter(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !datacenters.contains(trimmed) else { return }
        
        datacenters.append(trimmed)
        saveDatacenters()
    }
    
    func removeDatacenter(_ name: String) {
        datacenters.removeAll { $0 == name }
        saveDatacenters()
    }
    
    func updateDatacenter(old: String, new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let index = datacenters.firstIndex(of: old) {
            datacenters[index] = trimmed
            saveDatacenters()
        }
    }
    
    func hasDatacenter(_ name: String) -> Bool {
        datacenters.contains(name)
    }
    
    // MARK: - Reset All
    
    func resetAll() {
        defaults.removeObject(forKey: commandKey)
        defaults.removeObject(forKey: loginCommandKey)
        defaults.removeObject(forKey: logoutCommandKey)
        defaults.removeObject(forKey: retryEnabledKey)
        defaults.removeObject(forKey: retryAttemptsKey)
        defaults.removeObject(forKey: retryDelayKey)
        defaults.removeObject(forKey: datacentersKey)
        loadDatacenters()
    }
}

