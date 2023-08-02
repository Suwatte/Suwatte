//
//  RealmActor.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import RealmSwift


// Reference: https://www.mongodb.com/docs/realm/sdk/swift/actor-isolated-realm/#define-a-custom-realm-actor
actor RealmActor {
    // An implicitly-unwrapped optional is used here to let us pass `self` to
    // `Realm(actor:)` within `init`
    internal var realm: Realm!
    init() async {
        realm = try! await Realm(actor: self)
    }
    
    func close() {
        realm = nil
    }
    
    func operation(_ task: @escaping () async throws -> Void) async {
        do {
            try await task()
        } catch {
            Logger.shared.error(error, "RealmActor")
        }
    }
}
