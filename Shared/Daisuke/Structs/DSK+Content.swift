//
//  DSK+Content.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation

enum ContentStatus: Int, CaseIterable, Hashable {
    case UNKNOWN, ONGOING, COMPLETED, CANCELLED, HIATUS
}

enum ReadingMode: Int, CaseIterable, Hashable {
    case PAGED_MANGA, // Page 2 <---- Page 1
         PAGED_COMIC, // Page 1 ----> Page 2
         VERTICAL,
         VERTICAL_SEPARATED, // Vertical with Slight Gap Between Pages
         NOVEL, // Opens In Novel Reader
         WEB // Opens using the chapters WebUrl

    var isPanelMode: Bool {
        switch self {
        case .NOVEL, .WEB:
            return false
        default:
            return true
        }
    }
}

extension DaisukeEngine.Structs {
    struct SuwatteContentIdentifier: Parsable, Hashable {
        var contentId: String
        var sourceId: String

        var id: String {
            "\(sourceId)||\(contentId)"
        }
    }

    struct URLContentIdentifer: Parsable {
        var contentId: String
        var chapterId: String?
    }

    struct Highlight: Parsable, Identifiable, Hashable {
        var id: String
        var covers: [String]
        var title: String

        var subtitle: String?
        var tags: [String]?

        var stats: Stats?
        var chapter: Chapter?

        struct Stats: Parsable, Hashable {
            var rating: Double?
            var views: Int?
            var follows: Int?
        }

        struct Chapter: Parsable, Hashable {
            var label: String
            var id: String
            var date: Date
            var badge: Int
        }
    }
}

extension DaisukeEngine.Structs {
    struct Content: Parsable, Identifiable, Hashable {
        var id: String
        var title: String
        var additionalTitles: [String]
        var status: ContentStatus
        var covers: [String]
        var creators: [String]
        var summary: String
        var adultContent: Bool
        var url: String
        var properties: [StoredProperty]
        var recommendedReadingMode: ReadingMode
        var chapters: [Chapter]?
        var trackerInfo: TrackerInfo?
        var includedCollections: [HighlightCollection]?
        var contentType: ExternalContentType

        struct TrackerInfo: Parsable, Hashable {
            var al: String?
            var mal: String?
            var kt: String?
            var mu: String?
        }
    }
}

extension DaisukeEngine.Structs.Highlight {
    static func placeholders() -> [Self] {
        var out = [Self]()
        for _ in 1 ... 30 {
            let entry = Self(id: UUID().uuidString, covers: [""], title: String.random(), subtitle: String.random(), tags: nil, stats: nil, chapter: nil)
            out.append(entry)
        }
        return out
    }

    static func withId(id: String) -> Self {
        .init(id: id, covers: [], title: "", subtitle: nil, tags: nil, stats: nil, chapter: nil)
    }
}
