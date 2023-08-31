//
//  JSC+RunnerInfo.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation
import RealmSwift

enum CatalogRating: Int, CaseIterable, PersistableEnum, Parsable {
    case SAFE, MIXED, NSFW
}
struct RunnerInfo: Parsable {
    let id: String
    let name: String
    let version: Double
    let website: String
    let rating: CatalogRating?
    let minSupportedAppVersion: String?
    let thumbnail: String?
    let supportedLanguages: [String]?
}
