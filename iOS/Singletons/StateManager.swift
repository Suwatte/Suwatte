//
//  StateManager.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-12.
//

import Combine
import Foundation
import Network
import Nuke
import UIKit

final class StateManager: ObservableObject {
    static let shared = StateManager()
    var networkState = NetworkState.unknown
    var ShowNSFWContent = false
    let monitor = NWPathMonitor()

    init() {
        registerNetworkObserver()
        updateAnilistNSFWSetting()
    }

    func didStateChange() {
        updateAnilistNSFWSetting()
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

    func updateAnilistNSFWSetting() {
        guard NetworkStateHigh else {
            return
        }
        Task {
            ShowNSFWContent = await Anilist.shared.nsfwEnabled()
        }
    }

    var NetworkStateHigh: Bool {
        networkState == .online || networkState == .unknown
    }

    func clearMemoryCache() {
        ImagePipeline.shared.configuration.imageCache?.removeAll()
    }
    
    func alert(title: String, message: String) {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        controller.addAction(action)
        KEY_WINDOW?.rootViewController?.present(controller, animated: true)
    }
}

extension StateManager {
    enum NetworkState {
        case unknown, online, offline
    }
}
