//
//  Backup+CreamAsset.swift
//  Suwatte (iOS)
//
//  Created by Seyden on 06.05.24.
//

import Foundation
import IceCream

struct CodableCreamAsset: Codable {
    var folder: String
    var key: String
    var data: String

    static func from(creamAsset: CreamAsset) -> Self {
        .init(folder: creamAsset.getFolder(), key: creamAsset.getKey(), data: String(decoding: creamAsset.storedData()!, as: UTF8.self))
    }
}
