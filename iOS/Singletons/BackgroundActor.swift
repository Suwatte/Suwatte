//
//  BackgroundActor.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-26.
//

import Foundation

@globalActor actor BGActor: GlobalActor {
    static let shared = PanelActor()
    static func run<T>(resultType _: T.Type = T.self, body: @Sendable () async throws -> T) async rethrows -> T where T: Sendable {
        try await body()
    }
}
