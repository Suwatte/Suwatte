//
//  Realm+CustomThumbnail.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-01.
//

import Foundation
import IceCream
import RealmSwift
import UIKit

extension RealmActor {
    func setCustomThumbnail(image: UIImage, id: String) async {
        do {
            let result = try await STTImageProvider.shared.saveImage(image, for: id)
            let obj = CustomThumbnail()
            obj.id = id
            obj.file = CreamAsset.create(object: obj, propName: CustomThumbnail.FILE_KEY, url: result)
            obj.isDeleted = false
            try! await realm.asyncWrite {
                realm.add(obj, update: .modified)
            }
            ToastManager.shared.info("Thumbnail Updated!")

        } catch {
            ToastManager.shared.error(error)
            Logger.shared.error("\(error)")
        }
    }

    func removeCustomThumbnail(id: String) async {
        guard let target = realm.objects(CustomThumbnail.self).where({ $0.id == id }).first else {
            return
        }
        try! await realm.asyncWrite {
            target.isDeleted = true
        }
    }

    func getCustomThumb(id: String) -> CustomThumbnail? {
        let target = realm.objects(CustomThumbnail.self).where { $0.id == id }.first
        return target
    }
}
