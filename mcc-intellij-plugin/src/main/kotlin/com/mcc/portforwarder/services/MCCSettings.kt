package com.mcc.portforwarder.services

import com.intellij.openapi.components.*
import com.intellij.util.xmlb.XmlSerializerUtil

/**
 * Settings service using PersistentStateComponent (правильный способ)
 */
@com.intellij.openapi.components.Service
@State(
    name = "MCCPortForwarderSettings",
    storages = [Storage("MCCPortForwarderSettings.xml")]
)
class MCCSettings : PersistentStateComponent<MCCSettings.State> {
    
    private var myState = State()
    
    data class State(
        var datacenters: MutableList<String> = mutableListOf("hc", "kc", "pc"),
        var forwardCommand: String = "/usr/local/bin/mcc tp-port-forward",
        var loginCommand: String = "/usr/local/bin/mcc login",
        var logoutCommand: String = "/usr/local/bin/mcc logout",
        var retryEnabled: Boolean = true,
        var retryAttempts: Int = 3,
        var retryDelay: Int = 5
    )
    
    override fun getState(): State = myState
    
    override fun loadState(state: State) {
        XmlSerializerUtil.copyBean(state, myState)
    }
    
    // Datacenters
    fun getDatacenters(): List<String> = myState.datacenters.toList()
    fun addDatacenter(dc: String) {
        if (dc.isNotBlank() && !myState.datacenters.contains(dc)) {
            myState.datacenters.add(dc)
        }
    }
    fun removeDatacenter(dc: String) {
        myState.datacenters.remove(dc)
    }
    fun replaceDatacenters(newDatacenters: List<String>) {
        myState.datacenters.clear()
        myState.datacenters.addAll(newDatacenters)
    }
    
    // Commands
    var forwardCommand: String
        get() = myState.forwardCommand
        set(value) { myState.forwardCommand = value }
    
    var loginCommand: String
        get() = myState.loginCommand
        set(value) { myState.loginCommand = value }
    
    var logoutCommand: String
        get() = myState.logoutCommand
        set(value) { myState.logoutCommand = value }
    
    // Retry
    var retryEnabled: Boolean
        get() = myState.retryEnabled
        set(value) { myState.retryEnabled = value }
    
    var retryAttempts: Int
        get() = myState.retryAttempts
        set(value) { myState.retryAttempts = value.coerceIn(1, 20) }
    
    var retryDelay: Int
        get() = myState.retryDelay
        set(value) { myState.retryDelay = value.coerceIn(1, 60) }
    
    // Reset
    fun resetToDefaults() {
        myState = State()
    }
    
    companion object {
        fun getInstance(): MCCSettings = service()
    }
}

