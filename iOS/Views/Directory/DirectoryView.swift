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
        LoadableView(load, $model.result) { value in
            if value.isEmpty {
                NoResultsView()
            } else {
                ResultsView(entries: value, builder: content)
            }
        }
        .conditional(fullSearch, transform: { view in
            view
                .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
        })
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(model.$query.debounce(for: .seconds(0.45), scheduler: DispatchQueue.main), perform: didRecieveQuery(_:))
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

    func load() {
        Task {
            await model.makeRequest()
        }
    }

    func didRecieveQuery(_ val: String) {
        if model.callFromHistory {
            model.callFromHistory.toggle()
            return
        }
        if !firstCall {
            firstCall.toggle()
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
}

struct RunnerDirectoryView: View {
    let runner: AnyRunner
    let request: DSKCommon.DirectoryRequest

    var body: some View {
        Group {
            switch runner.environment {
            case .plugin:
                EmptyView()
            case .tracker:
                ContentTrackerDirectoryView(tracker: runner as! AnyContentTracker, request: request)
            case .source:
                ContentSourceDirectoryView(source: runner as! AnyContentSource, request: request)
            case .unknown:
                EmptyView()
            }
        }
    }
}
