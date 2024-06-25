//
//  Backup+Collection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import IceCream

struct CodableCustomThumbnail : Codable {
    var id: String
    var fileId: String

    static func from(customThumbnail: CustomThumbnail) -> Self {
        .init(id: customThumbnail.id, fileId: customThumbnail.file!.getKey())
    }
}
