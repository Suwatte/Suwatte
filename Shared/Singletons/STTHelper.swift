//
//  STTHelper.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-24.
//

import Foundation
import ReadiumOPDS
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

    static func getInitialPosition(for chapter: StoredChapter, limit: Int) -> (Int, CGFloat?) {
        guard let marker = DataManager.shared.getChapterMarker(forId: chapter._id) else {
            return (0, nil)
        }

        if marker.lastPageRead > limit || marker.lastPageRead < 0 || marker.completed {
            return (0, nil)
        }

        if let lastOffset = marker.lastPageOffset {
            return (marker.lastPageRead - 1, CGFloat(lastOffset))
        }
        return (marker.lastPageRead - 1, nil)
    }

    @MainActor
    static func getChapterData(_ chapter: StoredChapter) async -> Loadable<StoredChapterData> {
        switch chapter.chapterType {
        case .LOCAL:
            let bookId = Int64(chapter.contentId)

            guard let bookId = bookId, let book = LocalContentManager.shared.getBook(withId: bookId) else {
                return .failed(LocalContentManager.Errors.DNE)
            }

            do {
                let arr = try LocalContentManager.shared.getImagePaths(for: book.url)
                let obj = StoredChapterData()
                obj.chapter = chapter
                obj.archivePaths = arr
                return .loaded(obj)
            } catch {
                return .failed(error)
            }
        case .EXTERNAL:
            // Get from ICDM
            do {
                let download = try ICDM.shared.getCompletedDownload(for: chapter._id)
                if let download = download {
                    let obj = StoredChapterData()
                    obj.chapter = chapter
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
            if let data = DataManager.shared.getChapterData(forId: chapter._id) {
                return .loaded(data)
            }
            // Get from source
            guard let source = DaisukeEngine.shared.getSource(with: chapter.sourceId) else {
                return .failed(DaisukeEngine.Errors.NamedError(name: "[DAISUKE]", message: "Source Not Found"))
            }
            do {
                let data = try await source.getChapterData(contentId: chapter.contentId, chapterId: chapter.chapterId)
                let stored = data.toStored(withStoredChapter: chapter)
                DataManager.shared.saveChapterData(data: stored)
                return .loaded(stored)
            } catch {
                return .failed(error)
            }
        case .OPDS:
            do {
                let obj = StoredChapterData()
                obj.chapter = chapter
                let baseLink = chapter.contentId
                let pageCount = chapter.chapterId.split(separator: "|").first

                guard let pageCount = pageCount, let count = Int(pageCount) else {
                    throw OPDSParserError.documentNotValid
                }
                let pages = Array(0 ..< count).map { num -> StoredChapterPage in
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
}
