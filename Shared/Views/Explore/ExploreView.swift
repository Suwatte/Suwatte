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
    @EnvironmentObject var source: DaisukeContentSource
    @StateObject var model = ViewModel()
    var body: some View {
        Group {
            if hasExplorePage {
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
        .environmentObject(source)
        .modifier(InteractableContainer(selection: $model.selection))
    }
    
    var hasExplorePage: Bool {
        if let source = source as? DaisukeEngine.LocalContentSource {
            return source.hasExplorePage
        }
        return false
    }
}

extension ExploreView {
    class ViewModel: ObservableObject {
        @Published var selection: HighlightIndentier?
    }
}
