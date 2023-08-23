//
//  BookmarksView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-03.
//

import RealmSwift
import SwiftUI

struct BookmarksView: View {
    let contentID: String
    
    @StateObject private var model: ViewModel = .init()
    var body: some View {
        Group {
            if let results = model.results {
                if results.isEmpty {
                    EmptyResultsView()
                } else {
                    ResultsView(results)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Bookmarks")
        .task {
            observe()
        }
        .onDisappear(perform: stop)
    }
    
    func observe() {
        Task {
            await model.observe(id: contentID)
        }
    }
    
    func stop() {
        model.stop()
    }
    
    func EmptyResultsView() -> some View {
        VStack(alignment: .center, spacing: 7) {
            Text("(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧")
                .font(.title3)
            
            Text("No Bookmarks")
                .font(.headline)
                .fontWeight(.light)
            
            Text("Long press a page in the reader to add a bookmark!")
                .font(.subheadline)
                .fontWeight(.thin)
        }
    }
    
    @ViewBuilder
    func ResultsView(_ results: [UpdatedBookmark]) -> some View {
        CollectionsView(results: results)
    }
    
}
