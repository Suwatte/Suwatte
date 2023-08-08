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
    @State var source: Loadable<AnyContentSource> = .idle

    var body: some View {
        LoadableView(loadSource, $source) { value in
            StateGate(viewModel: .init(entry, value))
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationViewStyle(.stack)
    }

    func loadSource() async {
        source = .loading
        do {
            let runner = try await DSK.shared.getContentSource(id: sourceId)
            source = .loaded(runner)
        } catch {
            source = .failed(error)
        }
    }
}
