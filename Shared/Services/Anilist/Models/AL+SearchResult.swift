//
//  AL+SearchResult.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-23.
//

import Foundation
import SwiftUI

extension Anilist {
    struct PageResponse: Decodable {
        var data: DataResponse

        struct DataResponse: Decodable {
            var Page: Page
        }
    }

    struct Page: Decodable {
        var pageInfo: PageInfo
        var media: [SearchResult]

        struct PageInfo: Decodable {
            var total: Int
            var perPage: Int
            var currentPage: Int
            var lastPage: Int
            var hasNextPage: Bool

            static var defualtPage: PageInfo {
                .init(total: 0, perPage: 0, currentPage: 0, lastPage: 0, hasNextPage: false)
            }
        }
    }

    struct SearchRequest: Codable, Hashable {
        var page = 1
        var type: MediaType?
        var isAdult: Bool?
        var onList: Bool?
        var search: String?
        var format: [MediaFormat]?
        var status: MediaStatus?
        var sort: [MediaSort] = [.POPULARITY_DESC, .SCORE_DESC]
        var countOfOrigin: String?
        var source: MediaSource?

        var season: MediaSeason?
        var seasonYear: Int?

        var year: String?

        var yearLesser: String?
        var yearGreater: String?

        var episodesLesser: Int?
        var episodesGreater: Int?

        var durationLesser: Int?
        var durationGreater: Int?

        var volumeLesser: Int?
        var volumeGreater: Int?

        var chapterLesser: Int?
        var chapterGreater: Int?

        var isLicensed: Bool?
        var licensedBy: [String]?

        var genres: [String]?
        var excludedGenres: [String]?

        var tags: [String]?
        var excludedTags: [String]?
        var minimumTagRank: Int?

        static var defaultMangaRequest: SearchRequest {
            .init(type: .manga)
        }

        static var defaultAnimeRequest: SearchRequest {
            .init(type: .anime)
        }
    }

    struct SearchResult: Codable, Identifiable, Equatable {
        static func == (lhs: Anilist.SearchResult, rhs: Anilist.SearchResult) -> Bool {
            lhs.id == rhs.id
        }

        var id: Int
        var type: MediaType
        var status: MediaStatus
        var isAdult: Bool
        var title: Title
        var coverImage: CoverImage
        var mediaListEntry: MediaList?

        struct Title: Codable {
            var userPreferred: String
        }

        struct CoverImage: Codable {
            var large: String
            var extraLarge: String
            var color: String?
        }

        struct MediaList: Codable {
            var id: Int
            var status: MediaListStatus
        }
    }

    enum MediaListStatus: String, Codable, CaseIterable {
        case CURRENT, PLANNING, COMPLETED, DROPPED, PAUSED, REPEATING

        var systemImage: String {
            switch self {
            case .CURRENT:
                return "play.circle"
            case .PLANNING:
                return "square.stack.3d.up"
            case .COMPLETED:
                return "checkmark.circle"
            case .DROPPED:
                return "trash.circle"
            case .PAUSED:
                return "pause.circle"
            case .REPEATING:
                return "repeat.circle"
            }
        }

        var color: Color {
            switch self {
            case .CURRENT:
                return .blue
            case .PLANNING:
                return .yellow
            case .COMPLETED:
                return .green
            case .DROPPED:
                return .red
            case .PAUSED:
                return .gray
            case .REPEATING:
                return .cyan
            }
        }

        func description(for type: MediaType) -> String {
            switch self {
            case .CURRENT:
                return type == .anime ? "Watching" : "Reading"
            case .PLANNING:
                return "Planning"
            case .COMPLETED:
                return "Completed"
            case .DROPPED:
                return "Dropped"
            case .PAUSED:
                return "Paused"
            case .REPEATING:
                return type == .anime ? "Rewatching" : "Repeating"
            }
        }
    }

    enum MediaSeason: String, Codable {
        case WINTER, SPRING, SUMMER, FALL
    }

    enum MediaSource: String, Codable {
        case ORIGINAL, MANGA, LIGHT_NOVEL, VISUAL_NOVEL, VIDEO_GAME, OTHER, NOVEL, DOUJINSHI, ANIME
        case WEB_NOVEL, LIVE_ACTION, COMIC, MULTIMEDIA_PROJECT, PICTURE_BOOK
    }

    enum MediaSort: String, Codable {
//        case ID
//        case ID_DESC
//        case TITLE_ROMAJI
//        case TITLE_ROMAJI_DESC
//        case TITLE_ENGLISH
//        case TITLE_ENGLISH_DESC
//        case TITLE_NATIVE
//        case TITLE_NATIVE_DESC
//        case TYPE
//        case TYPE_DESC
//        case FORMAT
//        case FORMAT_DESC
        case START_DATE
        case START_DATE_DESC
        case END_DATE
        case END_DATE_DESC
        case SCORE
        case SCORE_DESC
        case POPULARITY
        case POPULARITY_DESC
        case TRENDING
        case TRENDING_DESC
        case EPISODES
        case EPISODES_DESC
        case DURATION
        case DURATION_DESC
        case STATUS
        case STATUS_DESC
        case CHAPTERS
        case CHAPTERS_DESC
        case VOLUMES
        case VOLUMES_DESC
        case UPDATED_AT
        case UPDATED_AT_DESC
        case SEARCH_MATCH
        case FAVOURITES
        case FAVOURITES_DESC

        static func getList(desc: Bool = true, type: MediaType) -> [MediaSort] {
            let asc: [MediaSort] = [
                //                .ID, .TITLE_ROMAJI, .TITLE_ENGLISH, .TITLE_NATIVE, .TYPE, .FORMAT,
                .START_DATE, .END_DATE, .SCORE, .POPULARITY, .TRENDING,
                .STATUS, .UPDATED_AT, .SEARCH_MATCH, .FAVOURITES,
            ]

            let descList: [MediaSort] = [
                //                .ID_DESC, .TITLE_ROMAJI_DESC, .TITLE_ENGLISH_DESC, .TITLE_NATIVE_DESC, .TYPE_DESC, .FORMAT_DESC
                .START_DATE_DESC, .END_DATE_DESC, .SCORE_DESC, .POPULARITY_DESC, .TRENDING_DESC,
                .STATUS_DESC, .UPDATED_AT_DESC, .SEARCH_MATCH, .FAVOURITES_DESC,
            ]

            var list = desc ? descList : asc

            let contentSpecific: [MediaSort] = desc ?
                type == .anime ? [.EPISODES_DESC, .DURATION_DESC] : [.CHAPTERS_DESC, .VOLUMES_DESC]
                : type == .anime ? [.EPISODES, .DURATION] : [.CHAPTERS, .VOLUMES]

            list.append(contentsOf: contentSpecific)
            return list
        }

        var description: String {
            switch self {
            case .SEARCH_MATCH: return "Best Search Matches"
//            case .ID, .ID_DESC: return "Content ID"
//            case .TITLE_NATIVE, .TITLE_NATIVE_DESC: return "Native Title"
//            case .TITLE_ENGLISH, .TITLE_ENGLISH_DESC: return "English Title"
//            case .TITLE_ROMAJI, .TITLE_ROMAJI_DESC: return "Romaji Title"
//            case .TYPE, .TYPE_DESC: return "Type"
//            case .FORMAT, .FORMAT_DESC: return "Format"
            case .START_DATE, .START_DATE_DESC: return "Start Date"
            case .END_DATE, .END_DATE_DESC: return "End Date"
            case .SCORE, .SCORE_DESC: return "Score"
            case .POPULARITY, .POPULARITY_DESC: return "Popularity"
            case .TRENDING, .TRENDING_DESC: return "Trending"
            case .STATUS, .STATUS_DESC: return "Status"
            case .UPDATED_AT, .UPDATED_AT_DESC: return "Updated At"
            case .FAVOURITES, .FAVOURITES_DESC: return "Favorites"
            case .EPISODES, .EPISODES_DESC: return "Episodes"
            case .DURATION, .DURATION_DESC: return "Duration"
            case .CHAPTERS, .CHAPTERS_DESC: return "Chapters"
            case .VOLUMES, .VOLUMES_DESC: return "Volumes"
            }
        }
    }
}
