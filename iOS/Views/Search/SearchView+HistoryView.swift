//
//  SearchView+HistoryView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-02.
//

import SwiftUI

extension SearchView {
    struct HistoryView: View {
        @FetchRequest(fetchRequest: CDSearchHistory.globalSearchRequest(), animation: .default)
        private var history: FetchedResults<CDSearchHistory>
        
        @EnvironmentObject var model: ViewModel
        var body: some View {
            List {
                ForEach(history) { entry in
                    Cell(entry: entry)
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                CDSearchHistory.remove(entry)
                            }
                        }
                }
            }
        }
    }
}

extension SearchView.HistoryView {
    struct Cell: View {
        @EnvironmentObject var model: SearchView.ViewModel
        let entry: CDSearchHistory
        var body: some View {
            Button {
                model.query = entry.display
                Task {
                    await model.makeRequests()
                }
            }
        label: {
            HStack {
                Text(entry.display)
                    .font(.headline)
                    .fontWeight(.light)
                Spacer()
                if let date = entry.date {
                    Text(date.timeAgo())
                        .font(.subheadline.weight(.light))
                }
                
            }
            
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        }
    }
}
