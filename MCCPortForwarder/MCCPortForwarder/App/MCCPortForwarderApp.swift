//
//  MCCPortForwarderApp.swift
//  MCCPortForwarder
//

import SwiftUI

@main
struct MCCPortForwarderApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Empty scene - app runs in status bar only
        Settings {
            EmptyView()
        }
    }
}

