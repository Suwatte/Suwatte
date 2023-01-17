//
//  DSK+Content.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation
struct ContentIdentifier: Parsable, Hashable {
    var contentId: String
    var sourceId: String

    var id: String {
        "\(sourceId)||\(contentId)"
    }
}

enum ContentStatus: Int, CaseIterable, Hashable {
    case UNKNOWN, ONGOING, COMPLETED, CANCELLED, HIATUS
}

enum ReadingMode: Int, CaseIterable, Hashable, UserDefaultsSerializable {
    case PAGED_MANGA, // Page 2 <---- Page 1
         PAGED_COMIC, // Page 1 ----> Page 2
         VERTICAL,
         VERTICAL_SEPARATED, // Vertical with Slight Gap Between Pages
         NOVEL, // Opens In Novel Reader
         WEB, // Opens using the chapters WebUrl
         PAGED_VERTICAL // A Vertical Pager

    var isPanelMode: Bool {
        switch self {
        case .NOVEL, .WEB:
            return false
        default:
            return true
        }
    }
}

enum PanelReadingModes: Int, CaseIterable, Hashable, UserDefaultsSerializable {
    case PAGED_MANGA, // Page 2 <---- Page 1
         PAGED_COMIC, // Page 1 ----> Page 2
         VERTICAL,
         VERTICAL_SEPARATED, // Vertical with Slight Gap Between Pages
         PAGED_VERTICAL // A Vertical Pager
}

extension DaisukeEngine.Structs {
    struct URLContentIdentifer: Parsable {
        var contentId: String
        var chapterId: String?
    }

    struct Highlight: Parsable, Identifiable, Hashable {
        var contentId: String
        var cover: String
        var additionalCovers: [String]?
        var title: String

        var subtitle: String?
        var tags: [String]?
        var stats: Stats?
        var updates: Updates?
        var id: String {
            contentId
        }

        var covers: [String] {
            var covers = additionalCovers ?? []
            covers.removeAll(where: { $0 == cover })
            covers.insert(cover, at: 0)
            return covers
        }

        struct Stats: Parsable, Hashable {
            var views: Int?
            var follows: Int?
            var rating: Double?
        }

        struct Updates: Parsable, Hashable {
            var label: String
            var date: Date?
            var count: Int?
        }
    }
}

extension DaisukeEngine.Structs {
    struct Content: Parsable, Hashable {
        var contentId: String
        var title: String
        var cover: String

        var additionalCovers: [String]?
        var webUrl: String?
        var status: ContentStatus?
        var creators: [String]?
        var summary: String?
        var adultContent: Bool?
        var additionalTitles: [String]?
        var properties: [Property]?
        var contentType: ExternalContentType?
        var recommendedReadingMode: ReadingMode?
        var nonInteractiveProperties: [NonInteractiveProperty]?
        var includedCollections: [HighlightCollection]?
        var trackerInfo: [String: String]?
        var chapters: [Chapter]?

        var covers: [String] {
            var covers = additionalCovers ?? []
            covers.removeAll(where: { $0 == cover })
            covers.insert(cover, at: 0)
            return covers
        }

        static let placeholder: Self = .init(contentId: .random(), title: .random(), cover: .random())
    }
}

extension DaisukeEngine.Structs.Highlight {
    static func placeholders() -> [Self] {
        (0 ... 30).map { _ in
                .init(contentId: .random(length: 10),
                      cover: .random(),
                      title: .random(length: 20),
                      tags: (0...5)
                    .map({ "\(String.random(length: 10))\($0)"})
                      , stats: .init(Stats(views: 100, follows: 100000, rating: 10)))
        }
    }

    static func withId(id: String) -> Self {
        .init(contentId: id, cover: String.random(), title: String.random())
    }
}
