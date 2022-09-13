//
//  StoredProperty.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import RealmSwift

final class StoredProperty: EmbeddedObject, Parsable {
    @Persisted var id: String
    @Persisted var label: String
    @Persisted var tags: List<StoredTag>
}

final class StoredTag: EmbeddedObject, ObjectKeyIdentifiable {
    @Persisted var id: String
    @Persisted var label: String
    @Persisted var adultContent: Bool
}

final class StoredTrackerInfo: EmbeddedObject, Parsable {
    @Persisted var al: String?
    @Persisted var mal: String?
    @Persisted var kt: String?
    @Persisted var mu: String?
}

final class ChapterProvider: EmbeddedObject, Parsable, Identifiable {
    @Persisted var id: String
    @Persisted var name: String
    @Persisted var links: List<ChapterProviderLink>
}

extension DSKCommon.ChapterProviderType: PersistableEnum {}

final class ChapterProviderLink: EmbeddedObject, Parsable {
    @Persisted var url: String
    @Persisted var type: DSKCommon.ChapterProviderType
}
