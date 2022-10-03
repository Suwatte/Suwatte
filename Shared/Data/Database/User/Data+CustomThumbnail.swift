//
//  Data+CustomThumbnail.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-10.
//

import Foundation
import RealmSwift
import UIKit

final class CustomThumbnail: Object, ObjectKeyIdentifiable {
    @Persisted var _id: String
    @Persisted var content: StoredContent? {
        didSet {
            if let content = content {
                _id = content._id
            }
        }
    }
}

extension DataManager {
    func setCustomThumbnail(image: UIImage, id: String) {
        let realm = try! Realm()

        guard let content = realm.objects(StoredContent.self).where({ $0._id == id }).first else {
            ToastManager.shared.display(.error(DaisukeEngine.Errors.RealmThawFailure))
            return
        }
        do {
            _ = try STTImageProvider.shared.saveImage(image, for: content._id)

            let object = CustomThumbnail()
            object.content = content

            try! realm.safeWrite {
                realm.add(object)
            }
        } catch {
            ToastManager.shared.display(.error(error))
        }
    }

    func removeCustomThumbnail(id: String) {
        let filename = id.appending(".jpg")
        let filepath = STTImageProvider.directory.appendingPathComponent(filename)

        try? FileManager.default.removeItem(at: filepath)
        let realm = try! Realm()

        if let obj = realm.objects(CustomThumbnail.self).first(where: { $0._id == id }) {
            try! realm.safeWrite {
                realm.delete(obj)
            }
        }
    }
}
