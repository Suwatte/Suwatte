//
//  ProfileView.swift
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
        LoadableSourceView(sourceID: sourceId) { source in
            StateGate(viewModel: .init(entry, source))
        }
        .navigationTitle(entry.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
