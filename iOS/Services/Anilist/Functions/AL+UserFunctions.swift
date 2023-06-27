//
//  AL+UserFunctions.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import Foundation

extension Anilist {
    private var CurrentViewerQuery: String {
        """
        query CurrentUser {
          Viewer {
            id
            name
            about
            avatar {
              large
            }
            bannerImage
            options {
              titleLanguage
              staffNameLanguage
              displayAdultContent
              profileColor
            }
            statistics {
              anime {
                count
                meanScore
                standardDeviation
                minutesWatched
                episodesWatched
                genrePreview: genres(limit: 10, sort: COUNT_DESC) {
                  genre
                  count
                }
              }
              manga {
                count
                meanScore
                standardDeviation
                chaptersRead
                volumesRead
                scorePreview: scores(limit: 10, sort: COUNT_DESC) {
                  count
                  score
                }
                statusPreview: statuses(limit: 10, sort: COUNT_DESC) {
                  count
                  meanScore
                  mediaIds
                  status
                }
                countryPreview: countries(limit: 10, sort: COUNT_DESC) {
                  meanScore
                  chaptersRead
                  mediaIds
                  country
                  count
                }
                genrePreview: genres(limit: 10, sort: COUNT_DESC) {
                  genre
                  count
                  meanScore
                }
                tagPreview: tags(limit: 10, sort: COUNT_DESC) {
                  tag {
                    id
                    name
                    category
                  }
                  count
                  meanScore
                }
              }
            }
            mediaListOptions {
              scoreFormat
              rowOrder
              animeList {
                customLists
                sectionOrder
                splitCompletedSectionByFormat
                advancedScoring
                advancedScoringEnabled
              }
              mangaList {
                customLists
                sectionOrder
                splitCompletedSectionByFormat
                advancedScoring
                advancedScoringEnabled
              }
            }
          }
        }
        """
    }

    func getUser() async throws -> User {
        return try await request(query: CurrentViewerQuery, to: UserResponse.self).data.Viewer
    }

    func nsfwEnabled() async -> Bool {
        do {
            let user = try await getUser()
            return user.options.displayAdultContent
        } catch {
            return false
        }
    }
}
