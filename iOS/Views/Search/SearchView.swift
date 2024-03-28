//
//  SearchView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import ASCollectionView
import RealmSwift
import SwiftUI

struct SearchView: View {
    typealias Highlight = DSKCommon.Highlight
    @State private var initial = true
    var initialQuery = ""
    @StateObject private var model = ViewModel()
    @State private var presentHistory = false
    @State private var presentImageSearch = false
    @State var searchTask: Task<Void, Never>?
    var body: some View {
        ZStack {
            if model.query.isEmpty {
                HistoryView()
                    .transition(.opacity)
            } else {
                if case .loaded = model.state, model.results.isEmpty {
                    NoResultsView()
                        .transition(.opacity)
                } else {
                    if model.state == .loading, model.results.isEmpty {
                        ProgressView()
                            .transition(.opacity)
                    } else {
                        CollectionView()
                            .transition(.opacity)
                            .task {
                                await model.observe()
                            }
                    }
                }
            }
        }
        .animation(.default, value: model.state)
        .animation(.default, value: model.results)
        .environmentObject(model)
        .navigationTitle("Search All")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always))
        .onSubmit(of: .search) {
            let request: DSKCommon.DirectoryRequest = .init(query: model.query, page: 1)
            let display = model.query
            CDSearchHistory.add(request, source: nil, label: display)
            searchTask?.cancel()
            searchTask = Task {
                await model.makeRequests()
            }
        }
        .task {
            if initialQuery.isEmpty || !initial { return }
            model.query = initialQuery
            await model.makeRequests()
            initial.toggle()
        }
        .animation(.default, value: model.query)
        .hiddenNav(presenting: $presentImageSearch) {
            ImageSearchView()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                StatusView
                MenuView
            }
        }
        .onDisappear {
            model.stopObserving()
        }
    }

    var MenuView: some View {
        Menu {
            Button {
                presentImageSearch.toggle()
            } label: {
                Label("Image Search", systemImage: "photo")
            }
            Divider()
            Button(role: .destructive) {
                CDSearchHistory.removeAll()
            } label: {
                Label("Clear History", systemImage: "xmark")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    var StatusView: some View {
        ZStack {
            switch model.state {
            case .loading:
                ProgressView()
                    .transition(.opacity)
            case .loaded:
                if hasEmpty || hasFailing {
                    Menu {
                        if hasEmpty {
                            Text("\(model.incomplete.noResults.count) source(s) with no results")
                        }
                        if hasFailing {
                            Text("\(model.incomplete.failing.count) source(s) failed.")
                        }
                    } label: {
                        Image(systemName: "info.circle")
                    }
                }
            default:
                EmptyView()
                    .transition(.opacity)
            }
        }
    }

    var hasFailing: Bool {
        !model.incomplete.failing.isEmpty
    }

    var hasEmpty: Bool {
        !model.incomplete.noResults.isEmpty
    }
}

extension SearchView {
    struct NoResultsView: View {
        var body: some View {
            VStack(spacing: 3.5) {
                Text("(─‿‿─)♡")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("no results.")
                    .font(.subheadline)
                    .fontWeight(.light)
            }
            .foregroundColor(.gray)
            .transition(.opacity)
        }
    }
}
