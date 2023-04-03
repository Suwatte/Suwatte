//
//  AL+User.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import Foundation

extension Anilist {
    struct UserResponse: Decodable {
        var data: ViewerResponse
    }

    struct ViewerResponse: Decodable {
        var Viewer: User
    }

    struct User: Decodable, Identifiable, Equatable {
        static func == (lhs: Anilist.User, rhs: Anilist.User) -> Bool {
            lhs.id == rhs.id
        }
        
        var id: Int
        var name: String
        var about: String?
        var bannerImage: String?
        var avatar: Avatar
        var statistics: UserStatisticType
        var mediaListOptions: MediaListOptions
    }

    struct Avatar: Decodable {
        var large: String?
    }

    struct UserStatisticType: Decodable {
        var manga: MangaStatistic
        var anime: AnimeStatistic
    }

    struct MangaStatistic: Decodable {
        var count: Int
        var meanScore: Double
        var standardDeviation: Double
        var chaptersRead: Int
        var volumesRead: Int
        var scorePreview: [Score]
        var genrePreview: [GenreStat]
        var tagPreview: [TagStat]
        var statusPreview: [StatusStat]
    }

    struct AnimeStatistic: Decodable {
        var count: Int
        var meanScore: Double
        var standardDeviation: Double
        var minutesWatched: Int
        var episodesWatched: Int
    }

    struct Score: Decodable {
        var count: Int
        var score: Int
    }

    struct GenreStat: Decodable {
        var genre: String
        var count: Int
        var meanScore: Double
    }

    struct TagInfo: Decodable {
        var id: Int
        var name: String
        var category: String
    }

    struct TagStat: Decodable {
        var tag: TagInfo
        var count: Int
        var meanScore: Double
    }

    struct MediaListOptions: Decodable {
        var scoreFormat: ScoreFormat

        enum ScoreFormat: String, Codable {
            case POINT_100, POINT_10_DECIMAL, POINT_10, POINT_5, POINT_3

            func getMax() -> Int? {
                switch self {
                case .POINT_100: return 100
                case .POINT_10, .POINT_10_DECIMAL: return 10
                default: return nil
                }
            }

            static let stars = ["-", "⭐️", "⭐️⭐️", "⭐️⭐️⭐️", "⭐️⭐️⭐️⭐️", "⭐️⭐️⭐️⭐️⭐️"]
            static let faces = ["-", "😐", "🙁", "😀"]
        }
    }

    enum MediaStatus: String, Codable {
        case FINISHED, RELEASING, NOT_YET_RELEASED, CANCELLED, HIATUS
    }

    enum MediaType: String, Codable {
        case anime = "ANIME", manga = "MANGA"

        var description: String {
            switch self {
            case .anime:
                return "Anime"
            case .manga:
                return "Manga"
            }
        }
    }

    enum MediaFormat: String, Codable {
        case TV, TV_SHORT, MOVIE, SPECIAL, OVA, ONA, MUSIC, MANGA, NOVEL, ONE_SHOT
    }

    struct StatusStat: Decodable {
        var status: MediaListStatus
        var count: Int
        var mediaIds: [Int]
        var meanScore: Double
    }
}
