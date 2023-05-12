//
//  AppState.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-12.
//

import Foundation
import Network
import Combine




final class StateManager : ObservableObject {
    static let shared = StateManager()
    var networkState = NetworkState.unknown
    let monitor = NWPathMonitor()
    
    init() {
        registerNetworkObserver()
    }
    
    func registerNetworkObserver() {
        let queue = DispatchQueue.global(qos: .background)
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                self?.networkState = .online
            } else {
                self?.networkState = .offline
            }
        }
    }
    
    var NetworkStateHigh: Bool {
        networkState == .online || networkState == .unknown 
    }
}


extension StateManager {
    enum NetworkState {
        case unknown, online, offline
    }
}
