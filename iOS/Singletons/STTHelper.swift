//
//  STTHelper.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-24.
//

import Foundation
import ReadiumOPDS
import RealmSwift
import UIKit
import CryptoKit

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

    static func getNavigationMode() -> ReaderView.ReaderNavigation.Modes {
        let isVertical = UserDefaults.standard.bool(forKey: STTKeys.IsReadingVertically)
        typealias Mode = ReaderView.ReaderNavigation.Modes
        if isVertical {
            let raw = UserDefaults.standard.integer(forKey: STTKeys.VerticalNavigator)

            return Mode(rawValue: raw)!
        } else {
            let raw = UserDefaults.standard.integer(forKey: STTKeys.PagedNavigator)

            return Mode(rawValue: raw)!
        }
    }

    static func getInitialPanelPosition(for id: String, chapterId: String, limit: Int) -> (Int, CGFloat?) {
        guard let marker = DataManager.shared.getContentMarker(for: id), let chapter = marker.currentChapter else {
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

    static func getChapterData(_ chapter: ThreadSafeChapter) async -> Loadable<StoredChapterData> {
        switch chapter.chapterType {
        case .LOCAL:
            let id = chapter.contentId
            let archivedContent = DataManager.shared.getArchivedcontentInfo(id)
            
            guard let archivedContent else {
                return .failed(DSK.Errors.NamedError(name: "DataLoader", message: "Failed to locate archive information"))
            }
            
            do {
                let url = archivedContent.getURL()
                guard let url else {
                    throw DSK.Errors.NamedError(name: "FileManager", message: "File not found.")
                }
                let arr = try ArchiveHelper().getImagePaths(for: url)
                let obj = StoredChapterData()
                obj.chapter = chapter.toStored()
                obj.archivePaths = arr
                obj.archiveURL = url
                return .loaded(obj)
                
            } catch {
                return .failed(error)
            }
        case .EXTERNAL:
            // Get from ICDM
            do {
                let download = try ICDM.shared.getCompletedDownload(for: chapter.id)
                if let download = download {
                    let obj = StoredChapterData()
                    obj.chapter = chapter.toStored()
                    obj.text = download.text
                    if let urls = download.urls {
                        obj.urls = urls
                    }
                    return .loaded(obj)
                }
            } catch {
                return .failed(error)
            }

            // Get from Database
            if let data = DataManager.shared.getChapterData(forId: chapter.id) {
                return .loaded(data.freeze())
            }
            // Get from source
            guard let source = DSK.shared.getSource(id: chapter.sourceId) else {
                return .failed(DaisukeEngine.Errors.NamedError(name: "Daisuke", message: "Source Not Found"))
            }
            do {
                let data = try await source.getChapterData(contentId: chapter.contentId, chapterId: chapter.chapterId)
                let stored = data.toStored(withStoredChapter: chapter.toStored())
                if !(source.config?.chapterDataCachingDisabled ?? false) {
                    DataManager.shared.saveChapterData(data: stored)
                }
                return .loaded(stored.realm == nil ? stored : stored.freeze())
            } catch {
                return .failed(error)
            }
        case .OPDS:
            do {
                let obj = StoredChapterData()
                obj.chapter = chapter.toStored()
                let baseLink = chapter.chapterId
                let publication = DataManager.shared.getPublication(id: chapter.contentId)
                guard let publication, let client = publication.client else {
                    throw DSK.Errors.NamedError(name: "OPDS", message: "Unable to fetch OPDS Content")
                }
                let pageCount = publication.pageCount
                let pages = Array(0 ..< pageCount).map { num -> StoredChapterPage in
                    let page = StoredChapterPage()
                    page.url = baseLink.replacingOccurrences(of: "STT_PAGE_NUMBER_PLACEHOLDER", with: num.description)
                    return page
                }

                let info = OPDSInfo(clientId: client.id, userName: client.userName)
                obj.pages.append(objectsIn: pages)
                obj.opdsInfo = info
                return .loaded(obj)
            } catch {
                return .failed(error)
            }
        }
    }

    static func optionalCompare<T: Comparable>(firstVal: T?, secondVal: T?) -> Bool {
        if let firstVal = firstVal, let secondVal = secondVal {
            return firstVal < secondVal
        } else {
            return firstVal == nil && secondVal == nil
        }
    }

    static func getAnilistID(id: String) -> Int? {
        let realm = try! Realm()

        guard let content = realm
            .objects(StoredContent.self)
            .where({ $0.id == id })
            .first
        else { return nil }

        if let value = content.trackerInfo["al"].flatMap(Int.init) {
            return value
        }

        if let value = DataManager.shared.getTrackerInfo(id)?.al.flatMap(Int.init) {
            return value
        }

        if let value = try? DataManager.shared.getPossibleTrackerInfo(for: id)?["al"]?.flatMap(Int.init) {
            return value
        }

        return nil
    }

    static func triggerHaptic(_ overrride: Bool = false) {
        if Preferences.standard.enableReaderHaptics || overrride {
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
}
