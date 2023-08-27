//
//  STTHelper.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-24.
//

import CryptoKit
import Foundation
import ReadiumOPDS
import RealmSwift
import UIKit

class STTHelpers {
    static func toggleSelection<T: Equatable>(list1: inout [T], list2: inout [T], element: T) {
        if list2.contains(element) {
            list2.removeAll(where: { $0 == element })
        } else if list1.contains(element) {
            list1.removeAll(where: { $0 == element })
            list2.append(element)
        } else {
            list1.append(element)
        }
    }

    static func getNavigationMode() -> ReaderNavigation.Modes {
        let isVertical = UserDefaults.standard.bool(forKey: STTKeys.IsReadingVertically)
        typealias Mode = ReaderNavigation.Modes
        if isVertical {
            let raw = UserDefaults.standard.integer(forKey: STTKeys.VerticalNavigator)

            return Mode(rawValue: raw)!
        } else {
            let raw = UserDefaults.standard.integer(forKey: STTKeys.PagedNavigator)

            return Mode(rawValue: raw)!
        }
    }

    static func getInitialPanelPosition(for id: String, chapterId: String, limit: Int) async -> (Int, CGFloat?) {
        let actor = await RealmActor()
        let marker = await actor.getContentMarker(for: id)
        guard let marker, let chapter = marker.currentChapter else {
            return (0, nil) // No Marker, Start from beginning
        }

        guard chapter.chapterId == chapterId else {
            return (0, nil) // Chapter is not the last read chapter, restart from beginnig
        }

        guard let lastPageRead = marker.lastPageRead else { // Marker has last page
            return (0, nil)
        }

        guard lastPageRead <= limit, lastPageRead > 0 else { // Marker is within bounds
            return (0, nil)
        }

        if lastPageRead == limit { // Chapter is completed, restart
            return (0, nil)
        }

        return (lastPageRead - 1, marker.lastPageOffset.flatMap(CGFloat.init))
    }

    static func optionalCompare<T: Comparable>(firstVal: T?, secondVal: T?) -> Bool {
        if let firstVal = firstVal, let secondVal = secondVal {
            return firstVal < secondVal
        } else {
            return firstVal == nil && secondVal == nil
        }
    }

    static func triggerHaptic(_ overrride: Bool = false) {
        Task { @MainActor in
            guard Preferences.standard.enableReaderHaptics || overrride else { return }
            let haptic = UIImpactFeedbackGenerator(style: .medium)
            haptic.impactOccurred()
        }
    }
}

extension STTHelpers {
    static func generateFileIdentifier(size: Int64, created: Date, modified: Date) -> String {
        let sizeHash = sha256(of: "\(size)")
        let createdHash = sha256(of: "\(created)")
        let modifiedHash = sha256(of: "\(modified)")

        let combinedHash = sizeHash + createdHash + modifiedHash
        return sha256(of: combinedHash)
    }

    static func generateFolderIdentifier(created: Date, name: String) -> String {
        let nameHash = sha256(of: "\(name)")
        let createdHash = sha256(of: "\(created)")
        return sha256(of: "\(nameHash)\(createdHash)")
    }

    static func sha256(of string: String) -> String {
        let data = string.data(using: .utf8)!
        let hashed = SHA256.hash(data: data)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

extension STTHelpers {
    static let LOCAL_CONTENT_ID = "7348b86c-ec52-47bf-8069-d30bd8382bf7"
    static let OPDS_CONTENT_ID = "c9d560ee-c4ff-4977-8cdf-fe9473825b8b"

    static func isInternalSource(_ id: String) -> Bool {
        return id == LOCAL_CONTENT_ID || id == OPDS_CONTENT_ID
    }
}

extension STTHelpers {
    static func getReadingMode(for id: String) -> ReadingMode? {
        let container = UserDefaults.standard
        let key = STTKeys.ReaderType + "%%" + id
        let value = container.object(forKey: key) as? Int
        return value.flatMap { ReadingMode(rawValue: $0) }
    }
}
