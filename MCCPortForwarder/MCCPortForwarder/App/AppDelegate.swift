//
//  AppDelegate.swift
//  MCCPortForwarder
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Setup status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.left.arrow.right.circle", accessibilityDescription: "MCC Port Forwarder")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Setup popover
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        self.popover = popover
        
        // Hide dock icon
        NSApplication.shared.setActivationPolicy(.accessory)
    }
    
    @objc private func togglePopover() {
        guard let popover = popover,
              let button = statusItem?.button else {
            return
        }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // Activate app to receive keyboard events
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup happens in AppViewModel deinit
    }
}

