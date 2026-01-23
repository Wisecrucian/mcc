//
//  StorageService.swift
//  MCCPortForwarder
//

import Foundation

final class StorageService {
    
    private let storageKey = "com.mcc.portforwarder.services"
    private let defaults = UserDefaults.standard
    
    // MARK: - Public Methods
    
    func saveServices(_ services: [Service]) {
        do {
            let data = try JSONEncoder().encode(services)
            defaults.set(data, forKey: storageKey)
        } catch {
            print("Failed to save services: \(error)")
        }
    }
    
    func loadServices() -> [Service] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }
        
        do {
            let services = try JSONDecoder().decode([Service].self, from: data)
            return services
        } catch {
            print("Failed to load services: \(error)")
            return []
        }
    }
}

