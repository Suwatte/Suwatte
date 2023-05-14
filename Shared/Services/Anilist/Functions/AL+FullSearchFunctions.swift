//
//  AL+FullSearchFunctions.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-23.
//

import Foundation
extension Anilist.Queries {
    static var SEARCH_RESULT_FRAGMENT = """
        fragment searchResult on Media {
              id
              title {
                userPreferred
              }
              coverImage {
                large
                extraLarge
                color
              }
              type
              status(version: 2)
              genres
              isAdult
              mediaListEntry {
                id
                status
              }
              countryOfOrigin
    }

    """
}

extension Anilist {
    static var FS_QUERY = """
    query FullSearch($page: Int = 1, $id: Int, $type: MediaType, $isAdult: Boolean, $search: String, $format: [MediaFormat], $status: MediaStatus, $countryOfOrigin: CountryCode, $source: MediaSource, $season: MediaSeason, $seasonYear: Int, $year: String, $onList: Boolean, $yearLesser: FuzzyDateInt, $yearGreater: FuzzyDateInt, $episodeLesser: Int, $episodeGreater: Int, $durationLesser: Int, $durationGreater: Int, $chapterLesser: Int, $chapterGreater: Int, $volumeLesser: Int, $volumeGreater: Int, $licensedBy: [String], $isLicensed: Boolean, $genres: [String], $excludedGenres: [String], $tags: [String], $excludedTags: [String], $minimumTagRank: Int, $sort: [MediaSort] = [POPULARITY_DESC, SCORE_DESC]) {
      Page(page: $page, perPage: 30) {
        pageInfo {
          total
          perPage
          currentPage
          lastPage
          hasNextPage
        }
        media(id: $id, type: $type, season: $season, format_in: $format, status: $status, countryOfOrigin: $countryOfOrigin, source: $source, search: $search, onList: $onList, seasonYear: $seasonYear, startDate_like: $year, startDate_lesser: $yearLesser, startDate_greater: $yearGreater, episodes_lesser: $episodeLesser, episodes_greater: $episodeGreater, duration_lesser: $durationLesser, duration_greater: $durationGreater, chapters_lesser: $chapterLesser, chapters_greater: $chapterGreater, volumes_lesser: $volumeLesser, volumes_greater: $volumeGreater, licensedBy_in: $licensedBy, isLicensed: $isLicensed, genre_in: $genres, genre_not_in: $excludedGenres, tag_in: $tags, tag_not_in: $excludedTags, minimumTagRank: $minimumTagRank, sort: $sort, isAdult: $isAdult) {

    ...searchResult
        }
      }
    }

    """

    static var GENRE_QUERY = """
    query {
      genres: GenreCollection
      tags: MediaTagCollection {
        name
        description
        category
        isAdult
      }
    }

    """
}

extension Anilist {
    func search(_ req: SearchRequest) async throws -> Page {
        var req = req
        req.isAdult = StateManager.shared.ShowNSFWContent && Preferences.standard.includeNSFWInAnilistSearchResult ? nil : false
        var data = try await request(query: Self.FS_QUERY + Queries.SEARCH_RESULT_FRAGMENT, variables: try req.asDictionary(), to: PageResponse.self).data.Page
        data.media = data.media.filter({ !($0.genres.count == 1 && $0.genres.contains("Hentai") && $0.countryOfOrigin == "JP") }) // Hard Filter Out Strictly hentai
        return data
    }

    func getTags() async throws -> GenreResponse.NestedVal {
        return try await request(query: Self.GENRE_QUERY, to: GenreResponse.self).data
    }
}
