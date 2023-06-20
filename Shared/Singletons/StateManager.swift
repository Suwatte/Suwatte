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
}

extension StateManager {
    enum NetworkState {
        case unknown, online, offline
    }
}
