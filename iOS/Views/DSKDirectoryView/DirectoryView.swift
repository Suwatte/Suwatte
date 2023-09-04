//
//  DirectoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import SwiftUI

struct DirectoryView<T: Codable & Hashable, C: View>: View {
    @StateObject var model: ViewModel
    @AppStorage(STTKeys.AppAccentColor) var accentColor: Color = .sttDefault
    @Environment(\.isSearching) private var isSearching: Bool

    var title: String?
    var content: (T) -> C
    @State var firstCall = false

    init(model: ViewModel, @ViewBuilder _ content: @escaping (T) -> C) {
        _model = StateObject(wrappedValue: model)
        self.content = content
    }

    var fullSearch: Bool {
        model.request.tag == nil && (model.config?.searchable ?? true)
    }

    var body: some View {
        Group {
            if fullSearch {
                LoadableResultsView
                    .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .automatic))
                    .onSubmit(of: .search) {
                        didRecieveQuery(model.query, save: true)
                    }
                    .onChange(of: model.query) { value in
                        if value.isEmpty && !isSearching {
                            model.reset()
                            request()
                        }
                    }
            } else {
                LoadableResultsView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $model.presentFilters) {
            FilterView(filters: model.filters)
                .tint(accentColor)
                .accentColor(accentColor)
        }
        .sheet(isPresented: $model.presentHistory) {
            HistoryView()
                .tint(accentColor)
                .accentColor(accentColor)
        }
        .task {
            guard let query = model.request.query, !model.result.LOADED else { return }
            model.query = query
        }
        .task {
            model.getConfig()
        }

        .environmentObject(model)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if fullSearch || !model.filters.isEmpty {
                    Button { model.presentFilters.toggle() } label: {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                    .badge(model.request.filters?.count ?? 0)
                    .disabled(model.filters.isEmpty)

                    Button { model.presentHistory.toggle() } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }
        }
    }

    func load() async {
        await model.makeRequest()
        firstCall = true
    }

    func didRecieveQuery(_ val: String, save: Bool = false) {
        if model.callFromHistory {
            model.callFromHistory.toggle()
            return
        }

        model.reset()

        if val.isEmpty {
            request()
            return
        }
        model.request.query = val
            .trimmingCharacters(in: .whitespacesAndNewlines)

        request()

        if save {
            Task {
                await RealmActor.shared().saveSearch(model.request, sourceId: model.runner.id, display: model.request.query ?? "")
            }
        }
    }

    func request() {
        Task {
            await model.makeRequest()
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
        LoadableView(load, $model.result) { value in
            Group {
                if value.isEmpty {
                    NoResultsView()
                } else {
                    ResultsView(entries: value, builder: content)
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
