//
//  Backup+Collection.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-06.
//

import Foundation
import IceCream

struct CodableCreamLocation: Codable {
    var longitude: Double
    var latitude: Double

    static func from(creamLocation: CreamLocation) -> Self {
        .init(longitude: creamLocation.longitude, latitude: creamLocation.latitude)
    }
}
