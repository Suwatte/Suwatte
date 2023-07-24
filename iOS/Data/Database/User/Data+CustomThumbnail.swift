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
    func setCustomThumbnail(image: UIImage, id: String) {
        let realm = try! Realm()

        do {
            let result = try STTImageProvider.shared.saveImage(image, for: id)
            let obj = CustomThumbnail()
            obj.id = id
            obj.file = CreamAsset.create(object: obj, propName: CustomThumbnail.FILE_KEY, url: result)
            obj.isDeleted = false
            try! realm.safeWrite {
                realm.add(obj, update: .modified)
            }
            ToastManager.shared.info("Thumbnail Updated!")

        } catch {
            ToastManager.shared.error(error)
            Logger.shared.error("\(error)")
        }
    }

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
