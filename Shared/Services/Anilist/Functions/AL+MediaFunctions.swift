//
//  AL+MediaFunctions.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-26.
//

import AnyCodable
import Foundation

extension Anilist {
    enum Queries {
        static var MEDIA_QUERY = """
        query Profile($id: Int, $type: MediaType, $isAdult: Boolean) {
          Media(id: $id, type: $type, isAdult: $isAdult) {
            ...profile
          }
        }
        """
        static var MEDIALIST_FRAGMENT = """
        fragment mediaListResult on MediaList {
            id
        userId
        mediaId
        status
        score
        progress
        progressVolumes
        repeat
        private
        priority
        notes
        hiddenFromStatusLists
        customLists(asArray: true)
        advancedScores
        startedAt {
        day
        month
        year
        }
        completedAt {
        day
        month
        year
        }
        updatedAt
        createdAt

        }
        """
        static var PROFILE_FRAGMENT = """
            fragment profile on Media {
                id
                title {
                  userPreferred
                  romaji
                  english
                  native
                }
                coverImage {
                  extraLarge
                  large
                  color
                }
                bannerImage
                startDate {
                  year
                  month
                  day
                }
                endDate {
                  year
                  month
                  day
                }
                description(asHtml: false)
                season
                seasonYear
                type
                format
                status(version: 2)
                episodes
                duration
                chapters
                volumes
                genres
                synonyms
        siteUrl
                source(version: 3)
                isAdult
                isLocked
                meanScore
                averageScore
                popularity
                favourites
                hashtag
                countryOfOrigin
                isLicensed
                isFavourite
                isRecommendationBlocked
                isFavouriteBlocked
        trending
                nextAiringEpisode {
                  airingAt
                  timeUntilAiring
                  episode
                }
                relations {
                  edges {
                    id
                    relationType(version: 2)
                    node {
                        ...searchResult
                    }
                  }
                }
                characterPreview: characters(perPage: 6, sort: [ROLE, RELEVANCE, ID]) {
                  edges {
                    id
                    role
                    name
                    voiceActors(language: JAPANESE, sort: [RELEVANCE, ID]) {
                      id
                      name {
                        userPreferred
                      }
                      language: languageV2
                      image {
                        large
                      }
                    }
                    node {
                      id
                      name {
                        userPreferred
                      }
                      image {
                        large
                      }
                    }
                  }
                }
                staffPreview: staff(perPage: 8, sort: [RELEVANCE, ID]) {
                  edges {
                    id
                    role
                    node {
                      id
                      name {
                        userPreferred
                      }
                      language: languageV2
                      image {
                        large
                      }
                    }
                  }
                }
                studios {
                  edges {
                    isMain
                    node {
                      id
                      name
                    }
                  }
                }
                recommendations(perPage: 25, sort: [RATING_DESC, ID]) {
                  pageInfo {
                    total
                  }
                  nodes {
                    id
                    rating
                    userRating
                    mediaRecommendation {
                      id
                      title {
                        userPreferred
                      }
                      format
                      type
                      status(version: 2)
                      bannerImage
                      coverImage {
                        large
                      }
                    }
                    user {
                      id
                      name
                      avatar {
                        large
                      }
                    }
                  }
                }
                externalLinks {
                  site
                  url
                }
                streamingEpisodes {
                  site
                  title
                  thumbnail
                  url
                }
                trailer {
                  id
                  site
                }
                rankings {
                  id
                  rank
                  type
                  format
                  year
                  season
                  allTime
                  context
                }
                tags {
                  id
                  name
                  description
                  rank
                  isMediaSpoiler
                  isGeneralSpoiler
                  userId
        isAdult
        category
                }
                mediaListEntry {
                  ...mediaListResult
                }
                stats {
                  statusDistribution {
                    status
                    amount
                  }
                  scoreDistribution {
                    score
                    amount
                  }
                }
            }
        """

        static var MEDIA_LIST_MUTATION = """
        mutation (
          $id: Int
          $mediaId: Int
          $status: MediaListStatus
          $score: Float
          $progress: Int
          $progressVolumes: Int
          $repeat: Int
          $private: Boolean
          $notes: String
          $customLists: [String]
          $hiddenFromStatusLists: Boolean
          $advancedScores: [Float]
          $startedAt: FuzzyDateInput
          $completedAt: FuzzyDateInput
        ) {
          SaveMediaListEntry(
            id: $id
            mediaId: $mediaId
            status: $status
            score: $score
            progress: $progress
            progressVolumes: $progressVolumes
            repeat: $repeat
            private: $private
            notes: $notes
            customLists: $customLists
            hiddenFromStatusLists: $hiddenFromStatusLists
            advancedScores: $advancedScores
            startedAt: $startedAt
            completedAt: $completedAt
          ) {
                  ...mediaListResult
          }
        }
        """
        
        static var MEDIA_RECOMMENDATION_QUERY = """
            query Profile($id: Int) {
              Media(id: $id) {
                recommendations(perPage: 25, sort: [RATING_DESC, ID]) {
                  pageInfo {
                    total
                  }
                  nodes {
                    mediaRecommendation {
                      id
                      title {
                        userPreferred
                      }
                      format
                      type
                      status(version: 2)
                      bannerImage
                      coverImage {
                        large
                        extraLarge
                      }
                    }
                  }
                }
              }
            }
            """
    }

}

extension Anilist {
    func getProfile(_ id: Int) async throws -> Media {
        return try await request(query: Queries.MEDIA_QUERY + Queries.PROFILE_FRAGMENT + Queries.SEARCH_RESULT_FRAGMENT + Queries.MEDIALIST_FRAGMENT, variables: ["id": id], to: MediaResponse.self).data.Media
    }

    @discardableResult
    func updateMediaListEntry(mediaId: Int, data: JSON) async throws -> Media.MediaListEntry {
        var variables = data
        variables["mediaId"] = mediaId
        return try await request(query: Queries.MEDIA_LIST_MUTATION + Queries.MEDIALIST_FRAGMENT, variables: variables, to: MediaResponse.MediaListResponse.self).data.SaveMediaListEntry
    }

    func updateMediaListEntry(entry: Media.MediaListEntry) async throws -> Media.MediaListEntry {
        let customLists = entry.customLists?.filter { $0.enabled }.map { $0.name }
        var variables = try entry.asDictionary()
        variables.updateValue(customLists as Any, forKey: "customLists")

        if !variables.keys.contains("notes") {
            variables["notes"] = ""
        }

        return try await request(query: Queries.MEDIA_LIST_MUTATION + Queries.MEDIALIST_FRAGMENT, variables: variables, to: MediaResponse.MediaListResponse.self).data.SaveMediaListEntry
    }

    @discardableResult
    func beginTracking(id: Int) async throws -> Media.MediaListEntry {
        let entry = try await getProfile(id)

        guard entry.mediaListEntry == nil else {
            return entry.mediaListEntry!
        }

        return try await updateMediaListEntry(mediaId: id,
                                              data: ["status": MediaListStatus.CURRENT.rawValue])
    }
    
    func getRecommendations(for id: Int) async throws -> Anilist.RecommendationResponse.PathObject {
        return try await request(query: Queries.MEDIA_RECOMMENDATION_QUERY,
                                 variables: ["id": id],
                                 to: Anilist.RecommendationResponse.self).data.Media.recommendations
    }
}
