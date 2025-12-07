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
         PAGED_VERTICAL,
         VERTICAL,
         WEB, // Opens using the chapters WebUrl
         NOVEL_PAGED_MANGA,
         NOVEL_PAGED_COMIC,
         NOVEL_PAGED_VERTICAL,
         NOVEL_WEBTOON

    var isPanelMode: Bool {
        switch self {
        case .NOVEL_WEBTOON, .NOVEL_PAGED_COMIC, .NOVEL_PAGED_VERTICAL, .NOVEL_PAGED_MANGA, .WEB:
            return false
        default:
            return true
        }
    }

    var isVertical: Bool {
        [Self.PAGED_VERTICAL, .VERTICAL].contains(self)
    }

    var isInverted: Bool {
        [Self.NOVEL_PAGED_MANGA, .PAGED_MANGA].contains(self)
    }

    var isHorizontalPager: Bool {
        isIn([.PAGED_COMIC, .PAGED_MANGA])
    }

    static func PanelCases() -> [Self] {
        allCases.filter { $0.isPanelMode }
    }

    static var defaultPanelMode: Self {
        Preferences.standard.defaultPanelReadingMode
    }

    var description: String {
        switch self {
        case .PAGED_MANGA:
            return "RTL (Manga)"
        case .PAGED_COMIC:
            return "LTR (Comic)"
        case .VERTICAL:
            return "Webtoon"
        case .PAGED_VERTICAL:
            return "Vertical Pager"
        case .WEB:
            return "WebView"
        case .NOVEL_WEBTOON:
            return "Vertical Scroll"
        case .NOVEL_PAGED_COMIC:
            return "Paged: Left to Right"
        case .NOVEL_PAGED_MANGA:
            return "Paged: Right to Left"
        case .NOVEL_PAGED_VERTICAL:
            return "Paged: Vertical"
        }
    }
}

enum ReaderScrollbarPosition: Int, CaseIterable, Hashable, UserDefaultsSerializable {
    case AUTO,
         BOTTOM,
         RIGHT,
         LEFT

    static func PositionCases() -> [Self] {
        allCases
    }

    static var defaultScrollbarPosition: Self {
        Preferences.standard.readerScrollbarPosition
    }

    func isVertical(_ isReadingModeVertical: Bool) -> Bool {
        switch self {
        case .AUTO:
            return isReadingModeVertical
        case .BOTTOM:
            return false
        default:
            return true
        }
    }

    var description: String {
        switch self {
        case .BOTTOM:
            return "Bottom"
        case .RIGHT:
            return "Right"
        case .LEFT:
            return "Left"
        case .AUTO:
            return "Auto"
        }
    }
}

enum ReaderBottomScrollbarDirection: Int, CaseIterable, Hashable, UserDefaultsSerializable {
    case RIGHT,
         LEFT

    static func DirectionCases() -> [Self] {
        allCases
    }

    static var defaultBottomScrollbarDirection: Self {
        Preferences.standard.readerBottomScrollbarDirection
    }

    var description: String {
        switch self {
        case .RIGHT:
            return "Right"
        case .LEFT:
            return "Left"
        }
    }
}

extension DaisukeEngine.Structs {
    struct Highlight: Parsable, Identifiable, Hashable {
        var id: String
        var cover: String
        var title: String

        var additionalCovers: [String]?
        var info: [String]?
        var subtitle: String?
        var badge: Badge?
        var context: CodableDict?
        var acquisitionLink: String?
        var streamable: Bool?
        var isNSFW: Bool?
        var link: Linkable?
        var noninteractive: Bool?
        var webUrl: String?
        var entry: TrackEntry?

        var canStream: Bool {
            streamable ?? false
        }

        var isNonInteractive: Bool {
            noninteractive ?? false
        }
    }

    struct Badge: JSCObject {
        let color: String?
        let count: Double?
    }
}

extension DaisukeEngine.Structs {
    struct Content: Parsable, Hashable {
        var title: String
        var cover: String
        var info: [String]?
        var additionalCovers: [String]?
        var webUrl: String?
        var status: ContentStatus?
        var creators: [String]?
        var summary: String?
        var additionalTitles: [String]?
        var properties: [Property]?
        var contentType: ExternalContentType?
        var recommendedPanelMode: ReadingMode?
        var collections: [HighlightCollection]?
        var trackerInfo: [String: String]?
        var chapters: [Chapter]?

        var acquisitionLink: String?
        var streamable: Bool?

        var isNSFW: Bool?

        var covers: [String] {
            var covers = additionalCovers ?? []
            covers.removeAll(where: { $0 == cover })
            covers.insert(cover, at: 0)
            return covers
        }

        var canStream: Bool {
            streamable ?? false
        }

        static let placeholder: Self = .init(title: .random(), cover: .random())
    }
}

extension DaisukeEngine.Structs.Highlight {
    static func placeholders() -> [Self] {
        (0 ... 30).map { _ in
            .init(id: .random(length: 10),
                  cover: .random(),
                  title: .random(length: 20), subtitle: .random(length: 15))
        }
    }

    static var placeholder: Self {
        .init(id: .random(length: 10),
              cover: .random(),
              title: .random(length: 20), subtitle: .random(length: 15))
    }

    static func withId(id: String) -> Self {
        .init(id: id, cover: String.random(), title: String.random())
    }
}

extension DSKCommon {
    struct ReaderContext: JSCObject {
        let target: String
        let chapters: [Chapter]
        let content: Highlight

        let requestedPage: Int?
        let readingMode: ReadingMode?
    }
}

extension DSKCommon {
    struct DeepLinkContext: JSCObject {
        let read: ReaderContext?
        let content: Highlight?
        let link: PageLinkLabel?
    }

    struct GroupedUpdateResponse: JSCObject {
        let updates: [GroupedUpdateItem]
    }

    struct GroupedUpdateItem: JSCObject {
        let contentId: String
        let updateCount: Int
    }

    struct ContentProgressState: JSCObject {
        let readChapterIds: [String]?
        let currentReadingState: CurrentReadingState?
        let markAllBelowAsRead: MarkState?

        struct CurrentReadingState: JSCObject {
            let page: Int
            let progress: Double
            let readDate: Date
            let chapterId: String
        }

        struct MarkState: JSCObject {
            let chapterNumber: Double
            let chapterVolume: Double?
        }
    }
}
