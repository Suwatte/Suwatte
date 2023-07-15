//
//  DSKPageView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import SwiftUI
import RealmSwift

struct DSKPageView<T: JSCObject, C: View> : View {
    @StateObject var model: ViewModel
    typealias PageItemModifier = (T) -> C
    let modifier: PageItemModifier
    
    init(model: ViewModel, @ViewBuilder _ modifier: @escaping PageItemModifier) {
        self._model = StateObject(wrappedValue: model)
        self.modifier = modifier
    }
    
    var body: some View {
        LoadableView(model.load, model.loadable) { page in
            CollectionView(page: page, runner: model.runner, modifier)
        }
        .environmentObject(model)
    }
}



extension DSKPageView {
    final class ViewModel : ObservableObject {
        let runner: JSCRunner
        let key: String
        @Published var loadable = Loadable<DSKCommon.Page<T>>.idle
        @Published var loadables: [String: Loadable<DSKCommon.ResolvedPageSection<T>>] = [:]
        @Published var errors = Set<String>()
        
        init(runner: JSCRunner, key: String) {
            self.runner = runner
            self.key = key
        }
        
        func load() {
            loadable = .loading
            Task {
                do {
                    let data: DSKCommon.Page<T> = try await runner.getPage(key: key) // Load Page
                    if !data.sections.allSatisfy({ $0.items != nil }) {
                        try await runner.willResolvePage(key: key) // Tell Runner that suwatte will begin resolution of page sections
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
            loadables[sectionID] = .loading
            errors.remove(sectionID)
            do {
                let data: DSKCommon.ResolvedPageSection<T> = try await runner.resolvePageSection(page: loadable.value!.key, section: sectionID)
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
    let pageKey: String
    var body: some View {
        Group {
            switch runner.environment {
            case .plugin:
                EmptyView()
            case .tracker:
                ContentTrackerPageView(tracker: runner as! JSCCT, pageKey: pageKey)
            case .source:
                ContentSourcePageView(source: runner as! JSCCS, pageKey: pageKey)
            case .unknown:
                EmptyView()
            }
        }
    }
}
