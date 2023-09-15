//
//  Landing+Source.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct SourceLandingPage: View {
    let sourceID: String
    @State var loadable = Loadable<AnyContentSource>.idle

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
        let source: AnyContentSource
        var body: some View {
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

    func load() async throws {
        await MainActor.run {
            loadable = .loading
        }
        let runner = try await DSK.shared.getContentSource(id: sourceID)
        await MainActor.run {
            loadable = .loaded(runner)
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

    func load() async throws {
        await MainActor.run {
            loadable = .loading
        }
        let runner = try await DSK.shared.getDSKRunner(runnerID)
        await MainActor.run {
            loadable = .loaded(runner)
        }
    }
}
