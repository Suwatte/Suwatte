//
//  DSK+Chapter.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-07-27.
//

import Foundation

extension DaisukeEngine.Structs {
    struct Chapter: Parsable, Identifiable, Hashable {
        var id: String
        var contentId: String
        var number: Double
        var volume: Double?
        var language: String
        var title: String?
        var date: Date
        var data: ChapterData?
        var providers: [DSKCommon.ChapterProvider]
        var index: Int
        var webUrl: String
    }

    struct ChapterData: Parsable, Identifiable, Hashable {
        var id: String
        var contentId: String
        var pages: [StoredChapterPage]
        var text: String?
    }

    struct ChapterProvider: Parsable, Hashable {
        var id: String
        var name: String
        var links: [ChapterProviderLink]
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
