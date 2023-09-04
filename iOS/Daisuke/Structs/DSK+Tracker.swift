//
//  DSK+Tracker.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-08.
//

import AnyCodable
import Foundation
import SwiftUI

// MARK: - Core

extension DSKCommon {
    enum TrackStatus: String, Codable, CaseIterable {
        case CURRENT, PLANNING, COMPLETED, PAUSED, DROPPED, REPEATING
    }

    struct TrackItem: Parsable, Hashable, Identifiable {
        let id: String
        let title: String
        let cover: String
        let webUrl: String
        var entry: TrackEntry?
        let info: [String]?
        let isNSFW: Bool?;
    }

    struct TrackProgress: Parsable, Hashable {
        var lastReadChapter: Double
        var lastReadVolume: Double?
        let maxAvailableChapter: Double?
    }

    struct TrackProgressUpdate: Parsable, Hashable {
        let chapter: Double?
        let volume: Double?
    }

    struct TrackEntry: Parsable, Hashable {
        var status: TrackStatus
        var progress: TrackProgress
    }
}

extension DSKCommon.TrackStatus {
    var description: String {
        switch self {
        case .CURRENT:
            return "Reading"
        case .PLANNING:
            return "Planning"
        case .COMPLETED:
            return "Completed"
        case .DROPPED:
            return "Dropped"
        case .PAUSED:
            return "Paused"
        case .REPEATING:
            return "Rereading"
        }
    }

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
}


extension DSKCommon {
    struct FullTrackItem: Parsable, Hashable {
        let id: String
        let title: String
        let cover: String
        let webUrl: String
        var entry: TrackEntry?
        let info: [String]?
        let isNSFW: Bool?

        let summary: String?
        let properites: [Property]?
        let bannerCover: String?
        let isFavorite: Bool?
        let relatedTitles: [TrackItem]?
        let recommendedTitles: [TrackItem]?
        let links: [TrackItemLink]?
        let additionalTitles: [String]?
        let status: ContentStatus?
        let characters: [TrackItemCharacter]?
    }
    
    struct TrackItemCharacter: Parsable, Hashable {
        let name: String
        let role: String?
        let image: String?
        let summary: String?
    }
    
    struct TrackItemLink: Parsable, Hashable, Identifiable {
        let label: String
        let url: String
        
        var id: Int {
            hashValue
        }
    }
}


extension DSKCommon.FullTrackItem {
    static var placeholder: Self {
        .init(id: "",
              title: "Placeholder Title",
              cover: "https://i.scdn.co/image/ab67616100005174d2d167f018561742f26a0997",
              webUrl: "https://google.com",
              info: nil,
              isNSFW: false,
              summary: "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
              properites: nil,
              bannerCover: nil,
              isFavorite: false,
              relatedTitles: nil,
              recommendedTitles: nil,
              links: nil,
              additionalTitles: ["Cheolhyeolgeomga Sanyanggaeui Hoegwi", "Yeokdaegeup Changgisaui", "Tama ni wa Uso wo Tsuku", "2 Level Hoegwihan Musin"],
              status: .ONGOING,
              characters: nil)
    }
}
