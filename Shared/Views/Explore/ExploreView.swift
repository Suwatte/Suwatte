//
//  ExploreView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import Nuke
import NukeUI
import RealmSwift
import SwiftUI
import UIKit

struct ExploreView: View {
    @StateObject var model: ViewModel
    @Preference(\.useDirectory) var useDirectory
    var body: some View {
        Group {
            if hasExplorePage && !useDirectory {
                ExploreCollectionViewRepresentable()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: SearchView(model: .init(source: model.source), usingDirectory: false)) {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
            } else {
                ExploreView.SearchView(model: .init(source: model.source))
            }
        }
        .navigationTitle(model.source.name)
        .environmentObject(model)
        .modifier(InteractableContainer(selection: $model.selection))
    }

    var hasExplorePage: Bool {
        model.source.config.hasExplorePage
    }
}

extension ExploreView {
    class ViewModel: ObservableObject {
        @Published var selection: HighlightIndentier?
        var source: AnyContentSource

        init(source: AnyContentSource) {
            self.source = source
        }
    }
}
