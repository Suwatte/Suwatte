//
//  ArchivedContent.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-06-21.
//

import Foundation
import IceCream
import NukeUI
import RealmSwift

final class ArchivedContent: Object, CKRecordConvertible, CKRecordRecoverable {
    @Persisted(primaryKey: true) var id: String
    @Persisted var relativePath: String
    @Persisted var name: String
    @Persisted var isDeleted: Bool
}

extension ArchivedContent {
    func getURL() -> URL? {
        let directory = CloudDataManager
            .shared
            .getDocumentDiretoryURL()
            .appendingPathComponent("Library", isDirectory: true)
        let target = directory
            .appendingPathComponent(relativePath)

        if target.exists {
            return target
        }

        guard CloudDataManager.shared.isCloudEnabled else { return nil }

        let resources = try? target.resourceValues(forKeys: [.isUbiquitousItemKey])
        if let resources, let isInCloud = resources.isUbiquitousItem, isInCloud {
            return target
        }

        return nil
    }
}
