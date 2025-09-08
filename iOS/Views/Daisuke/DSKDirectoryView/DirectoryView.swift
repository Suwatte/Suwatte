//
//  DirectoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import SwiftUI

struct DirectoryView<C: View>: View {
    @StateObject var model: ViewModel
    @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
    @Environment(\.isSearching) private var isSearching: Bool
    
    var title: String?
    var content: (DSKCommon.Highlight) -> C
    @State var text = ""
    
    init(model: ViewModel, @ViewBuilder _ content: @escaping (DSKCommon.Highlight) -> C) {
        _model = StateObject(wrappedValue: model)
        self.content = content
    }
    
    var body: some View {
        LoadableResultsView
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $model.presentFilters) {
                FilterView(filters: model.filters)
                    .tint(accentColor)
                    .accentColor(accentColor)
            }
            .sheet(isPresented: $model.presentHistory, onDismiss: reload) {
                HistoryView()
                    .tint(accentColor)
                    .accentColor(accentColor)
            }
            .task {
                guard let query = model.request.query, !model.result.LOADED else { return }
                model.query = query
            }
        
            .environmentObject(model)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if model.fullSearch {
                        Button { model.presentFilters.toggle() } label: {
                            Image(systemName: "line.3.horizontal.decrease")
                        }
                        .disabled(model.filters.isEmpty)
                        
                        Button { model.presentHistory.toggle() } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                    }
                }
            }
    }
    
    func reload() {
        model.result = .idle
        model.pagination = .IDLE
    }
    
    func load() async throws -> [DSKCommon.Highlight] {
        try await model.sendRequest()
    }
    
    func didRecieveQuery(_ val: String, save: Bool = false) {
        if model.callFromHistory {
            model.callFromHistory.toggle()
            return
        }
        
        model.reset()
        
        if val.isEmpty {
            reload()
            return
        }
        model.request.query = val
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        reload()
        
        if save {
            Task {
                await RealmActor.shared().saveSearch(model.request, sourceId: model.runner.id, display: model.request.query ?? "")
            }
        }
    }
}

extension DirectoryView {
    struct NoResultsView: View {
        var body: some View {
            VStack {
                Text("┐(´～｀)┌")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text("No results...")
                    .font(.subheadline)
                    .fontWeight(.light)
            }
        }
    }
    
    var LoadableResultsView: some View {
        LoadableView(model.runner.id, load, $model.result) { value in
            if value.isEmpty {
                NoResultsView()
            } else {
                ResultsView(entries: value, builder: content)
            }
        }
        .conditional(model.fullSearch) { view in
            view
                .searchable(text: $model.query, placement: .toolbar)
                .onSubmit(of: .search) {
                    didRecieveQuery(model.query, save: true)
                }
                .onChange(of: model.query) { value in
                    if value.isEmpty && !isSearching {
                        model.reset()
                        reload()
                    }
                }
        }
    }
}

struct RunnerDirectoryView: View {
    let runner: AnyRunner
    let request: DSKCommon.DirectoryRequest
    
    var body: some View {
        Group {
            switch runner.environment {
            case .tracker:
                ContentTrackerDirectoryView(tracker: runner as! AnyContentTracker, request: request)
            case .source:
                ContentSourceDirectoryView(source: runner as! AnyContentSource, request: request)
            case .unknown:
                Text("Unknown Runner Environment")
            }
        }
    }
}
