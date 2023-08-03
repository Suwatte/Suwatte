//
//  DSKPageView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import RealmSwift
import SwiftUI

struct DSKPageView<T: JSCObject, C: View>: View {
    @StateObject var model: ViewModel
    typealias PageItemModifier = (T) -> C
    let modifier: PageItemModifier

    init(model: ViewModel, @ViewBuilder _ modifier: @escaping PageItemModifier) {
        _model = StateObject(wrappedValue: model)
        self.modifier = modifier
    }

    var body: some View {
        LoadableView(model.load, model.loadable) { sections in
            CollectionView(sections: sections, runner: model.runner, modifier)
        }
        .environmentObject(model)
    }
}

extension DSKPageView {
    final class ViewModel: ObservableObject {
        let runner: JSCRunner
        let link: DSKCommon.PageLink
        @Published var loadable = Loadable<[DSKCommon.PageSection<T>]>.idle
        @Published var loadables: [String: Loadable<DSKCommon.ResolvedPageSection<T>>] = [:]
        @Published var errors = Set<String>()

        init(runner: JSCRunner, link: DSKCommon.PageLink) {
            self.runner = runner
            self.link = link
        }

        func load() {
            Task {
                await MainActor.run {
                    loadable = .loading
                }
                do {
                    let data: [DSKCommon.PageSection<T>] = try await runner.getSectionsForPage(link: link) // Load Page
                    if !data.allSatisfy({ $0.items != nil }) {
                        try await runner.willResolveSectionsForPage(link: link) // Tell Runner that suwatte will begin resolution of page sections
                    }
                    await MainActor.run {
                        withAnimation {
                            loadable = .loaded(data)
                        }
                    }
                } catch {
                    Logger.shared.error(error, runner.id)
                    await MainActor.run {
                        withAnimation {
                            loadable = .failed(error)
                        }
                    }
                }
            }
        }

        func load(_ sectionID: String) async {
            await MainActor.run {
                loadables[sectionID] = .loading
                errors.remove(sectionID)
            }
            do {
                let data: DSKCommon.ResolvedPageSection<T> = try await runner.resolvePageSection(link: link, section: sectionID)
                await MainActor.run {
                    loadables[sectionID] = .loaded(data)
                }
            } catch {
                Logger.shared.error(error, runner.id)
                await MainActor.run {
                    loadables[sectionID] = .failed(error)
                    errors.insert(sectionID)
                }
            }
        }
    }
}

struct RunnerPageView: View {
    let runner: JSCRunner
    var link: DSKCommon.PageLink
    var body: some View {
        Group {
            switch runner.environment {
            case .plugin:
                EmptyView()
            case .tracker:
                ContentTrackerPageView(tracker: runner as! JSCCT, link: link)
            case .source:
                ContentSourcePageView(source: runner as! JSCCS, link: link)
            case .unknown:
                EmptyView()
            }
        }
    }
}
