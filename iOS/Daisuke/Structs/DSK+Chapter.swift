//
//  DSK+Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation

extension DaisukeEngine.Structs {
    struct Chapter: Parsable, Hashable, STTChapterObject {
        let chapterId: String
        let number: Double
        let language: String
        let volume: Double?
        let title: String?
        let date: Date
        let data: ChapterData?
        let providers: [DSKCommon.ChapterProvider]?
        let index: Int
        let webUrl: String?
        let thumbnail: String?
    }

    struct ChapterData: Parsable, Hashable {
        var pages: [ChapterPage]?
        var text: String?
    }

    struct ChapterPage: Parsable, Hashable {
        var url: String?
        var raw: String?
    }

    struct ChapterProvider: Parsable, Hashable, Identifiable {
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
              volume: (volume == nil || volume == 0.0) ? nil : volume,
              title: title,
              language: language,
              date: date,
              webUrl: webUrl,
              thumbnail: thumbnail,
              providers: providers)
    }
}
