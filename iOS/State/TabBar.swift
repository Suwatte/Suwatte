//
//  TabBar.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Foundation
import SwiftUI

enum AppTabs: Int, CaseIterable {
    case downloads, feed, more, library, browse, history

    var id: Int {
        hashValue
    }

    @MainActor
    @ViewBuilder
    func view() -> some View {
        switch self {
        case .downloads:
            SourceDownloadView()
                .protectContent()
        case .feed:
            SmartNavigationView {
                UpdateFeedView()
            }
            .protectContent()
        case .more:
            MoreView()
        case .library:
            SmartNavigationView {
                LibraryView()
            }
            .protectContent()
        case .browse:
            BrowseView()
        case .history:
            SmartNavigationView {
                HistoryView()
            }
            .protectContent()
        }
    }

    func label() -> String {
        switch self {
        case .downloads:
            return "Download Queue"
        case .feed:
            return "Feed"
        case .more:
            return "More"
        case .library:
            return "Library"
        case .browse:
            return "Browse"
        case .history:
            return "History"
        }
    }

    @MainActor
    func systemImage() -> String {
        switch self {
        case .downloads:
            return "square.and.arrow.down"
        case .feed:
            let hasNotifs = UIApplication.shared.applicationIconBadgeNumber > 0
            return hasNotifs ? "bell.badge" : "bell"
        case .more:
            return "ellipsis.circle"
        case .library:
            return "books.vertical"
        case .browse:
            return "safari"
        case .history:
            return "clock"
        }
    }

    static let defaultSettings: [AppTabs] = [.library, .feed, .history, .browse, .more]
}

struct SmartNavigationView<Content>: View where Content: View {
    let content: () -> Content

    var body: some View {
        NavigationView(content: content)
            .navigationViewStyle(.stack)
    }
}
