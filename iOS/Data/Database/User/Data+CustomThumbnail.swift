//
//  Data+CustomThumbnail.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-10.
//

import Foundation
import IceCream
import RealmSwift
import UIKit

extension DataManager {

    func removeCustomThumbnail(id: String) {
        let realm = try! Realm()

        guard let target = realm.objects(CustomThumbnail.self).where({ $0.id == id }).first else {
            return
        }
        try! realm.safeWrite {
            target.isDeleted = true
        }
    }

    func getCustomThumb(id: String) -> CustomThumbnail? {
        let realm = try! Realm()
        let target = realm.objects(CustomThumbnail.self).where { $0.id == id }.first
        return target
    }
}
