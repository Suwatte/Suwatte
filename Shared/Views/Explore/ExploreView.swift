//
//  ExploreView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import ASCollectionView
import Nuke
import NukeUI
import RealmSwift
import SwiftUI
import UIKit

struct ExploreView: View {
    @EnvironmentObject var source: DaisukeEngine.ContentSource
    @StateObject var model = ViewModel()
    var body: some View {
        Group {
            if source.sourceInfo.hasExplorePage {
                ExploreCollectioViewRepresentable()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink(destination: SearchView(model: .init(request: .init(), source: source))) {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
            } else {
                ExploreView.SearchView(model: .init(request: .init(), source: source))
            }
        }
        .navigationTitle(source.name)
        .environmentObject(model)
        .modifier(InteractableContainer(selection: $model.selection))
    }
}

extension ExploreView {
    class ViewModel: ObservableObject {
        @Published var selection: HighlightIndentier?
    }
}
