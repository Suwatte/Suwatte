//
//  PV+Source.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-13.
//

import SwiftUI

struct ContentSourcePageView: View {
    let source: JSCCS
    var pageKey: String = "home"
    @StateObject private var model = ContentSourceDirectoryView.ViewModel()
    @StateObject var manager = LocalAuthManager.shared
    @Preference(\.protectContent) var protectContent
    @State private var selection: HighlightIndentier?
    var body: some View {
        DSKPageView<DSKCommon.Highlight, Cell>(model: .init(runner: source, key: pageKey)) { item in
            Cell(sourceID: source.id, item: item, inLibrary: model.library.contains(item.contentId), inReadLater: model.readLater.contains(item.contentId), hideLibraryBadges: hideLibrayBadges, selection: $selection)
        }
        .task {
            model.start(source.id)
        }
        .onDisappear(perform: model.stop)
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
    
    
    struct Cell: View {
        let sourceID: String
        let item: DSKCommon.Highlight
        let inLibrary: Bool
        @State var inReadLater: Bool
        let hideLibraryBadges: Bool
        
        @Binding var selection: HighlightIndentier?
        
        
        var body: some View {
            ZStack(alignment: .topTrailing) {
                PageViewTile(runnerID: sourceID, id: item.contentId, title: item.title, cover: item.cover, additionalCovers: item.additionalCovers, info: item.info)
                if let color = badgeColor() {
                    ColoredBadge(color: color)
                        .transition(.opacity)
                }
            }
            .contextMenu {
                Button {
                    if inReadLater {
                        DataManager.shared.removeFromReadLater(sourceID, content: item.contentId)
                    } else {
                        DataManager.shared.addToReadLater(sourceID, item.contentId)
                    }
                } label: {
                    Label(inReadLater ? "Remove from Read Later" : "Add to Read Later", systemImage: inReadLater ? "bookmark.slash" : "bookmark")
                }
            }
            .onTapGesture {
                selection = (sourceID, item)
            }
        }
        
        func badgeColor() -> Color? {
            let libraryBadge = (inLibrary || inReadLater) && !hideLibraryBadges
            if libraryBadge {
                return inLibrary ? .accentColor : .yellow
            }
            return nil
        }
    }
}
