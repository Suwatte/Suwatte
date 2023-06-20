//
//  ExploreView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-02-28.
//

import RealmSwift
import SwiftUI
import UIKit

struct ExploreView: View {
    @State var loadable = Loadable<AnyContentSource>.idle
    var id: String
    var name: String
    var body: some View {
        LoadableView(getSource, loadable) { source in
            SourceView(model: .init(source: source))
        }
        .navigationTitle(name)
    }

    func getSource() {
        loadable = .loading
        do {
            let source = try SourceManager.shared.getContentSource(id: id)
            loadable = .loaded(source)
        } catch {
            loadable = .failed(error)
        }
    }
}

extension ExploreView {
    struct SourceView: View {
        @StateObject var model: ViewModel
        @Preference(\.useDirectory) var useDirectory
        var hasExplorePage: Bool {
            model.source.config.hasExplorePage
        }

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
                        .onDisappear {
                            Task {
                                StateManager.shared.clearMemoryCache()
                            }
                        }
                } else {
                    ExploreView.SearchView(model: .init(source: model.source))
                }
            }
            .modifier(InteractableContainer(selection: $model.selection))
            .environmentObject(model)
        }
    }

    class ViewModel: ObservableObject {
        @Published var selection: HighlightIndentier?
        var source: AnyContentSource

        init(source: AnyContentSource) {
            self.source = source
        }
    }
}
