//
//  SearchView+HIstoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import SwiftUI

extension SearchView {
    struct HistoryView: View {
        @EnvironmentObject var model: ViewModel
        var body: some View {
            List {
                ForEach(model.history) { entry in
                    Cell(entry: entry)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task {
                                    let actor = await RealmActor.shared()
                                    await actor.deleteSearch(entry.id)
                                    await model.loadSearchHistory()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            }
            .task {
                await model.loadSearchHistory()
            }
        }
    }
}

extension SearchView.HistoryView {
    struct Cell: View {
        @EnvironmentObject var model: SearchView.ViewModel
        let entry: UpdatedSearchHistory
        var body: some View {
            Button {
                model.query = entry.displayText
                Task {
                    await model.makeRequests()
                }
            }
            label: {
                HStack {
                    Text(entry.displayText)
                        .font(.headline)
                        .fontWeight(.light)
                    Spacer()
                    Text(entry.date.timeAgo())
                        .font(.subheadline.weight(.light))
                }

                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

extension SearchView.ViewModel {
    func loadSearchHistory() async {
        let actor = await RealmActor.shared()
        let data = await actor.getAllSearchHistory()
        await MainActor.run {
            withAnimation {
                history = data
            }
        }
    }
}
