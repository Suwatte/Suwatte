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
            obj.file = CreamAsset.create(object: obj, folder: CustomThumbnail.FILE_KEY, url: result)
            obj.isDeleted = false
            await operation {
                realm.add(obj, update: .modified)
            }
            ToastManager.shared.info("Thumbnail Updated!")

        } catch {
            ToastManager.shared.error(error)
            Logger.shared.error("\(error)")
        }
    }

    func removeCustomThumbnail(id: String) async {
        guard let target = getObject(of: CustomThumbnail.self, with: id) else {
            return
        }
        await operation {
            target.isDeleted = true
        }
    }

    func getCustomThumb(id: String) -> CustomThumbnail? {
        getObject(of: CustomThumbnail.self, with: id)?.freeze()
    }
}
