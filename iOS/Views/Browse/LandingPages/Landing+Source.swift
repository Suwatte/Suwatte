//
//  ContentSourceLandingPage.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct SourceLandingPage: View {
    let sourceID: String
    @State var loadable = Loadable<JSCCS>.idle

    var body: some View {
        LoadableView(startSource, $loadable) {
            LoadedSourceView(source: $0)
        }
    }

    func startSource() async throws {
        loadable = .loading
        let runner = try await DSK.shared.getContentSource(id: sourceID)
        loadable = .loaded(runner)
    }

    struct LoadedSourceView: View {
        let source: JSCCS
        var body: some View {
            Group {
                if source.intents.pageLinkResolver {
                    ContentSourcePageView(source: source, link: .init(key: "home", context: nil))
                } else {
                    ContentSourceDirectoryView(source: source, request: .init(page: 1))
                }
            }
        }
    }
}
