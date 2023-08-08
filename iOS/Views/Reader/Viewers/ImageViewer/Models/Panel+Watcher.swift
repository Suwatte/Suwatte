//
//  Panel+Watcher.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-06.
//

import Foundation
import Combine



final class PanelPublisher {
    static let shared = PanelPublisher()
    
    let willSplitPage = PassthroughSubject<PanelPage, Never>()
    
}
