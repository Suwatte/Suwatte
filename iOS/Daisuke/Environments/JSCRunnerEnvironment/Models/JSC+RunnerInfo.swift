//
//  JSC+RunnerInfo.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-03.
//

import Foundation

struct RunnerInfo: Parsable {
    let id: String
    let name: String
    let version: Double
    let website: String
    let minSupportedAppVersion: String?
    let thumbnail: String?
    let supportedLanguages: [String]?
    let nsfw: Bool?
}
