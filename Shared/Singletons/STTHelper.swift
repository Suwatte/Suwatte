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
        
        guard lastPageRead <= limit && lastPageRead > 0 else { // Marker is within bounds
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
            let bookId = Int64(chapter.contentId)

            guard let bookId = bookId, let book = LocalContentManager.shared.getBook(withId: bookId) else {
                return .failed(LocalContentManager.Errors.DNE)
            }

            do {
                let arr = try LocalContentManager.shared.getImagePaths(for: book.url)
                let obj = StoredChapterData()
                obj.chapter = chapter.toStored()
                obj.archivePaths = arr
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
            guard let source = try? SourceManager.shared.getContentSource(id: chapter.sourceId) else {
                return .failed(DaisukeEngine.Errors.NamedError(name: "SourceManager", message: "Source Not Found"))
            }
            do {
                let data = try await source.getChapterData(contentId: chapter.contentId, chapterId: chapter.chapterId)
                let stored = data.toStored(withStoredChapter: chapter.toStored())
                if !source.config.chapterDataCachingDisabled {
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
  
                let pages = Array(0 ..< 10).map { num -> StoredChapterPage in
                    let page = StoredChapterPage()
                    page.url = baseLink.replacingOccurrences(of: "STT_PAGE_NUMBER_PLACEHOLDER", with: num.description)
                    return page
                }

                obj.pages.append(objectsIn: pages)
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
