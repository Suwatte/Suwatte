//
//  LibraryCollection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import IceCream
import RealmSwift

final class LibraryCollection: Object, CKRecordConvertible, CKRecordRecoverable, Identifiable {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var name: String
    @Persisted var pinningType: TitlePinningType?
    @Persisted var order: Int
    @Persisted var filter: LibraryCollectionFilter?
    @Persisted var isDeleted: Bool
}

enum TitlePinningType: Int, PersistableEnum, CaseIterable, Codable {
    case none, unread, updated

    var description: String {
        switch self {
        case .none:
            return "None"
        case .unread:
            return "Unread"
        case .updated:
            return "Updated"
        }
    }

    static let pinTypes: [TitlePinningType] = [.unread, .updated]
}
