package com.mcc.portforwarder.services

import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.intellij.openapi.components.*
import com.intellij.util.xmlb.XmlSerializerUtil
import com.mcc.portforwarder.models.MCCServiceModel

/**
 * Storage service for services persistence
 */
@com.intellij.openapi.components.Service
@State(
    name = "MCCPortForwarderStorage",
    storages = [Storage("MCCPortForwarderStorage.xml")]
)
class MCCStorage : PersistentStateComponent<MCCStorage.State> {
    
    private var myState = State()
    private val gson: Gson = GsonBuilder().setPrettyPrinting().create()
    
    data class State(
        var servicesJson: String = "[]"
    )
    
    override fun getState(): State = myState
    
    override fun loadState(state: State) {
        XmlSerializerUtil.copyBean(state, myState)
    }
    
    fun saveServices(services: List<MCCServiceModel>) {
        try {
            myState.servicesJson = gson.toJson(services)
        } catch (e: Exception) {
            // Log error
        }
    }
    
    fun loadServices(): MutableList<MCCServiceModel> {
        return try {
            if (myState.servicesJson.isBlank() || myState.servicesJson == "[]") {
                mutableListOf()
            } else {
                val array = gson.fromJson(myState.servicesJson, Array<MCCServiceModel>::class.java)
                array.toMutableList()
            }
        } catch (e: Exception) {
            mutableListOf()
        }
    }
    
    companion object {
        fun getInstance(): MCCStorage = service()
    }
}

