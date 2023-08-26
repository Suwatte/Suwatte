//
//  DSK+Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation

extension DaisukeEngine.Structs {
    struct Chapter: Parsable, Hashable {
        var chapterId: String
        var number: Double
        var language: String
        var volume: Double?
        var title: String?
        var date: Date
        var data: ChapterData?
        var providers: [DSKCommon.ChapterProvider]?
        var index: Int
        var webUrl: String?
        var thumbnail: String?
    }

    struct ChapterData: Parsable, Hashable {
        var chapterId: String
        var contentId: String
        var pages: [ChapterPage]?
        var text: String?
    }

    struct ChapterPage: Parsable, Hashable {
        var url: String?
        var raw: String?
    }

    struct ChapterProvider: Parsable, Hashable {
        var id: String
        var name: String
        var links: [ChapterProviderLink]?
    }

    struct ChapterProviderLink: Parsable, Hashable {
        var url: String
        var type: ChapterProviderType
    }

    enum ChapterProviderType: Int, CaseIterable, Codable {
        case WEBSITE,
             TWITTER,
             DISCORD,
             PATREON

        var description: String {
            switch self {
            case .WEBSITE:
                return "Website"
            case .TWITTER:
                return "Twitter"
            case .DISCORD:
                return "Discord"
            case .PATREON:
                return "Patreon"
            }
        }
    }
}


extension DSKCommon.Chapter {
    func toThreadSafe(sourceID: String, contentID: String) -> ThreadSafeChapter {
        .init(id: "\(sourceID)||\(contentID)||\(chapterId)",
              sourceId: sourceID,
              chapterId: chapterId,
              contentId: contentID,
              index: index,
              number: number,
              volume: volume,
              title: title,
              language: language,
              date: date,
              webUrl: webUrl,
              thumbnail: thumbnail,
              providers: providers)
    }
}
