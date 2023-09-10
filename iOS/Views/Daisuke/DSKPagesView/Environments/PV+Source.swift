//
//  PV+Source.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct ContentSourcePageView: View {
    let source: AnyContentSource
    var link: DSKCommon.PageLink
    @StateObject private var model = ContentSourceDirectoryView.ViewModel()
    @StateObject var manager = LocalAuthManager.shared
    @Preference(\.protectContent) var protectContent
    @State private var selection: HighlightIdentifier?

    var pageKey: String {
        link.key
    }

    var body: some View {
        DSKPageView<DSKCommon.Highlight, DSKHighlightTile>(model: .init(runner: source, link: link)) { item in
            let identifier = ContentIdentifier(contentId: item.contentId,
                                               sourceId: source.id).id
            
             DSKHighlightTile(data: item,
                              source: source,
                              inLibrary: model.library.contains(identifier),
                              inReadLater: model.readLater.contains(identifier),
                              selection: $selection,
                              hideLibraryBadges: hideLibrayBadges)
         
        }
        .task {
            await model.start(source.id)
        }
        .onDisappear(perform: model.stop)
        .animation(.default, value: model.library)
        .animation(.default, value: model.readLater)
        .modifier(InteractableContainer(selection: $selection))
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                NavigationLink {
                    AllTagsView(source: source)
                } label: {
                    Image(systemName: "tag")
                }
                .opacity(pageKey == "home" && source.intents.hasTagsView ? 1 : 0)
                NavigationLink {
                    ContentSourceDirectoryView(source: source, request: .init(page: 1))
                        .navigationTitle("Search \(source.name)")
                } label: {
                    Image(systemName: "magnifyingglass")
                }
                .opacity(pageKey == "home" ? 1 : 0)
            }
        }
    }

    var hideLibrayBadges: Bool {
        protectContent && manager.isExpired
    }
}
