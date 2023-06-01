//
//  OPDSContent.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-05-30.
//

import Foundation
import RealmSwift
import IceCream


final class StoredOPDSContent: Object {
    @Persisted(primaryKey: true) var contentLink: String
    @Persisted var contentTitle: String
    @Persisted var contentThumbnail: String
    @Persisted var client: StoredOPDSServer?
}
