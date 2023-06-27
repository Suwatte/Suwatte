//
//  ContentProfileView.swift
//  Suwatte
//
//  Created by Mantton on 2022-03-06.
//

import SwiftUI

struct ProfileView: View {
    var entry: DaisukeEngine.Structs.Highlight
    var sourceId: String

    @State var initialized = false
    var body: some View {
        Group {
            if let source = try? SourceManager.shared.getContentSource(id: sourceId) {
                StateGate(viewModel: .init(entry, source))
            } else {
                NoMatchingIDView
            }
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationViewStyle(.stack)
    }

    var NoMatchingIDView: some View {
        Text("No Source Matching Provided ID Found")
    }
}
