//
//  AL+Data.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-25.
//

import Foundation

extension Anilist {
    struct MediaResponse: Decodable {
        var data: ResponseData

        struct ResponseData: Decodable {
            var Media: Media
        }

        struct MediaListResponse: Decodable {
            var data: ResponseData

            struct ResponseData: Decodable {
                var SaveMediaListEntry: Media.MediaListEntry
            }
        }
    }

    struct Media: Decodable, Equatable {
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.id == rhs.id
        }

        var id: Int
        var idMal: Int?
        var title: MediaTitle
        var type: MediaType
        var format: MediaFormat
        var status: MediaStatus
        var description: String?
        var startDate: FuzzyDate
        var endDate: FuzzyDate
        var season: MediaSeason?
        var seasonYear: Int?
        var episodes: Int?
        var duration: Int?
        var chapters: Int?
        var volumes: Int?
        var countryOfOrigin: String
        var isLiscensed: Bool?
        var source: MediaSource?
        var hashtag: String?
        var trailer: MediaTrailer?
        var updatedAt: Int?
        var coverImage: MediaCoverImage
        var bannerImage: String?
        var genres: [String]
        var synonyms: [String]
        var averageScore: Int?
        var meanScore: Int?
        var popularity: Int
        var isLocked: Bool
        var trending: Int
        var favourites: Int
        var tags: [MediaTag]
        var isFavourite: Bool
        var isFavouriteBlocked: Bool
        var isAdult: Bool
        var siteUrl: String
        var rankings: [MediaRank]
        var stats: MediaStats?
        var relations: MediaConnection
//        var characters: CharacterConnection
        var mediaListEntry: MediaListEntry?

        struct MediaListEntry: Codable, Hashable {
            var id: Int
            var userId: Int
            var mediaId: Int
            var status: MediaListStatus
            var score: Double
            var progress: Int
            var progressVolumes: Int?
            var `repeat`: Int
            var priority: Int
            var `private`: Bool
            var notes: String?
            var hiddenFromStatusLists: Bool
            var customLists: [CustomList]?
            var startedAt: FuzzyDate
            var completedAt: FuzzyDate
            var updatedAt: Int
            var createdAt: Int
            var advancedScores: AdvancedScores

            struct AdvancedScores: Codable, Hashable {}

            struct CustomList: Codable, Hashable {
                var name: String
                var enabled: Bool
            }
        }

        var webUrl: URL? {
            let path = type == .manga ? "manga" : "anime"
            return URL(string: "https://anilist.co/\(path)/\(id)")
        }
    }
}

extension Anilist.Media {
    struct MediaTitle: Decodable {
        var romaji: String?
        var english: String?
        var native: String?
        var userPreferred: String
    }

    struct MediaTrailer: Decodable {
        var id: String
        var site: String
        var thumbnail: String?
    }

    struct MediaCoverImage: Decodable {
        var extraLarge: String
        var large: String
        var medium: String?
        var color: String?
    }

    struct MediaTag: Decodable, Identifiable {
        var id: Int
        var name: String
        var description: String?
        var category: String
        var rank: Int
        var isGeneralSpoiler: Bool
        var isMediaSpoiler: Bool
        var isAdult: Bool
    }

    struct MediaExternalLink: Decodable {
        var id: Int
        var url: String
        var site: String
        var icon: String
        var color: String
        var notes: String
        var type: LinkType

        enum LinkType: String, Decodable {
            case INFO, STREAMING, SOCIAL
        }
    }

    struct MediaRank: Decodable {
        var id: Int
        var rank: Int
        var type: RankType
        var format: RankFormat
        var context: String
        var allTime: Bool
        var season: Anilist.MediaSeason?
        var year: Int?
        enum RankType: String, Decodable {
            case POPULAR, RATED
        }

        enum RankFormat: String, Decodable {
            case TV, TV_SHORT, MOVIE, SPECIAL
            case OVA, ONA, MUSIC, MANGA, NOVEL, ONE_SHOT
        }
    }
}

extension Anilist.Media {
    struct MediaStats: Decodable {
        var scoreDistribution: [ScoreDistribution]?
        var statusDistribution: [StatusDistribution]?
    }

    struct ScoreDistribution: Decodable {
        var score: Int
        var amount: Int
    }

    struct StatusDistribution: Decodable {
        var status: Anilist.MediaListStatus
        var amount: Int
    }

    struct MediaConnection: Decodable {
        var edges: [Edge]

        struct Edge: Decodable {
            var node: Anilist.SearchResult
            var relationType: MediaRelation
            var id: Int
        }
    }

    struct CharacterConnection: Decodable {
        var edges: [Edge]

        struct Edge: Decodable {
            var node: Character
            var id: Int
            var role: Character.Role
            var name: String
        }
    }

    struct Character: Decodable {
        enum Role: String, Decodable {
            case MAIN, SUPPORTING, BACKGROUND
        }
    }

    enum MediaRelation: String, Decodable {
        case ADAPTATION, PREQUEL, SEQUEL
        case PARENT, SIDE_STORY, CHARACTER, SUMMARY
        case ALTERNATIVE, SPIN_OFF, OTHER, SOURCE
        case COMPILATION, CONTAINS
    }
}

extension Anilist {
    struct FuzzyDate: Codable, Hashable {
        var year: Int?
        var month: Int?
        var day: Int?

        func toDate() -> Date? {
            guard let year = year, let month = month, let day = day else {
                return nil
            }

            let components = DateComponents(year: year, month: month, day: day)
            return Calendar.current.date(from: components)
        }
    }
}

extension Date {
    func toFuzzyDate() -> Anilist.FuzzyDate {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: self)
        return .init(year: components.year, month: components.month, day: components.day)
    }
}

extension Anilist {
    struct RecommendationResponse: Decodable {
        var data: Media

        struct Media: Decodable {
            var Media: ExternalNodeObject
        }

        struct ExternalNodeObject: Decodable {
            var recommendations: PathObject
        }

        struct PathObject: Decodable, Equatable {
            static func == (lhs: Anilist.RecommendationResponse.PathObject, rhs: Anilist.RecommendationResponse.PathObject) -> Bool {
                lhs.id == rhs.id
            }
            
            var pageInfo: PageInfo
            var nodes: [InternalNodeObject]
            var id = UUID().uuidString
            
            
        }

        struct PageInfo: Decodable {
            var total: Int
        }

        struct InternalNodeObject: Decodable {
            var mediaRecommendation: Excerpt
        }

        struct Excerpt: Decodable {
            var id: Int
            var title: Anilist.Media.MediaTitle
            var coverImage: Anilist.Media.MediaCoverImage
        }
    }
}
