//
//  DSK+CS+Tags.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation
import JavaScriptCore

// MARK: Tags

extension DaisukeEngine.LocalContentSource {}

// MARK: Explore Section

extension DaisukeEngine.LocalContentSource {
    
    func willResolveExploreCollections() async throws {
        do {
            try await callOptionalVoidMethod(method: "willResolveExploreCollections", arguments: [])
        } catch {
            ToastManager.shared.display(.error(nil, "[\(id)] [willResolveExploreCollections] \(error.localizedDescription)"))
        }
    }
}
