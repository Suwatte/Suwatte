//
//  CollectionFilter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-06-11.
//

import Foundation
import RealmSwift

class CollectionFilter: EmbeddedObject {
    @Persisted var value: String
    @Persisted var type: FilterType

    enum FilterType: Int, PersistableEnum {
        case TITLE, TAGS, UNREAD_COUNT, STATUS, ORIGINAL_LANG, ADULT_CONTENT
    }
}
