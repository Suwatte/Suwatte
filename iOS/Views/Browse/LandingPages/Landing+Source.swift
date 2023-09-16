//
//  Landing+Source.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct LoadableSourceView<V: View>: View {
    let sourceID: String
    let content: (AnyContentSource) -> V
    @State var loadable: Loadable<AnyContentSource> = .idle

    init(sourceID: String, @ViewBuilder _ content: @escaping (AnyContentSource) -> V) {
        self.sourceID = sourceID
        self.content = content
    }

    var body: some View {
        LoadableView(load, $loadable) { value in
            content(value)
        }
    }

    func load() async throws -> AnyContentSource {
        try await DSK.shared.getContentSource(id: sourceID)
    }
}

struct SourceLandingPage: View {
    let sourceID: String
    @State var loadable = Loadable<AnyContentSource>.idle

    var body: some View {
        LoadableSourceView(sourceID: sourceID) { source in
            Group {
                if source.intents.pageLinkResolver {
                    ContentSourcePageView(source: source, link: .init(id: "home", context: nil))
                } else {
                    ContentSourceDirectoryView(source: source, request: .init(page: 1))
                }
            }
        }
    }
}



struct LoadableRunnerView<V: View>: View {
    let runnerID: String
    let content: (AnyRunner) -> V
    @State var loadable: Loadable<AnyRunner> = .idle

    init(runnerID: String, @ViewBuilder _ content: @escaping (AnyRunner) -> V) {
        self.runnerID = runnerID
        self.content = content
    }

    var body: some View {
        LoadableView(load, $loadable) { value in
            content(value)
        }
    }

    func load() async throws -> AnyRunner {
        try await DSK.shared.getDSKRunner(runnerID)
    }
}
