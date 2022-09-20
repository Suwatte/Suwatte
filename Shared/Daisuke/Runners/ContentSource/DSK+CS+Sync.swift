//
//  DSK+CS+Sync.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-08-16.
//

import Foundation

extension DSK.ContentSource {
    func getReadChapterMarkers(for id: String) async throws -> [String] {
        try await withCheckedThrowingContinuation { handler in
            let methodName = "getReadChapterMarkers"
            guard methodExists(method: methodName) else {
                handler.resume(throwing: DSK.Errors.MethodNotFound(name: methodName))
                return
            }

            runnerClass.daisukeCall(method: methodName, arguments: [id]) { value in
                guard let value = value.toArray() as? [String] else {
                    handler.resume(throwing: DSK.Errors.ObjectConversionFailed)
                    return
                }
                handler.resume(returning: value)
            } onFailure: { error in
                handler.resume(throwing: error)
            }
        }
    }
}
