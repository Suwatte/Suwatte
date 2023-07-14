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
        DSKPageView(model: .init(runner: source, key: pageKey)) { item in
            Cell(item)
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
    
    @ViewBuilder
    func Cell( _ item : DSKCommon.PageSectionItem) -> some View {
        let id = item.id ?? ""
        let inReadLater = model.readLater.contains(id)
        ZStack(alignment: .topTrailing) {
            PageViewTile(entry: item, runnerID: source.id)
            if let color = badgeColor(for: id, item.badgeColor){
                ColoredBadge(color: color)
                    .transition(.opacity)
            }
        }
        .contextMenu {
            Button {
                if inReadLater {
                    DataManager.shared.removeFromReadLater(source.id, content: id)
                } else {
                    DataManager.shared.addToReadLater(source.id, id)
                }
            } label: {
                Label(inReadLater ? "Remove from Read Later" : "Add to Read Later", systemImage: inReadLater ? "bookmark.slash" : "bookmark")
            }
        }
        .onTapGesture {
            let highlight: DSKCommon.Highlight = .init(contentId: id, cover: item.cover ?? "", title: item.title ?? "")
            selection = (source.id, highlight)
        }
    }
    
    func badgeColor(for id: String, _ badge: String?) -> Color? {
        let inLibrary = model.library.contains(id)
        let inReadLater = model.readLater.contains(id)
        let libraryBadge = (inLibrary || inReadLater) && !hideLibrayBadges
        
        if libraryBadge {
            return inLibrary ? .accentColor : .yellow
        }
        
        if let badge {
            return Color.init(hex: badge)
        }
        
        return nil
    }
}
