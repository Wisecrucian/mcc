package com.mcc.portforwarder.services

import com.intellij.openapi.components.*

data class MCCSettings(
    var command: String = "/usr/local/bin/mcc tp-port-forward",
    var loginCommand: String = "/usr/local/bin/mcc login",
    var logoutCommand: String = "/usr/local/bin/mcc logout",
    var retryEnabled: Boolean = true,
    var retryAttempts: Int = 3,
    var retryDelay: Int = 5,
    var datacenters: List<String> = listOf("dc1", "dc2", "dc3")
)

@Service(Service.Level.APP)
@State(
    name = "MCCPortForwarderSettings",
    storages = [Storage("MCCPortForwarder.xml")]
)
class MCCSettingsService : PersistentStateComponent<MCCSettings> {
    private var settings = MCCSettings()

    override fun getState(): MCCSettings = settings

    override fun loadState(state: MCCSettings) {
        settings = state
    }

    fun getSettings(): MCCSettings = settings

    fun updateSettings(newSettings: MCCSettings) {
        settings = newSettings
    }

    companion object {
        fun getInstance(): MCCSettingsService = service()
    }
}

