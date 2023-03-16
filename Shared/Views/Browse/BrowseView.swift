//
//  BrowseView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-03-27.
//

import Kingfisher
import RealmSwift
import SwiftUI

struct BrowseView: View {
    @StateObject var manager = SourceManager.shared
    @ObservedResults(StoredRunnerObject.self) var runners
    @State var presentImporter = false
    var body: some View {
        NavigationView {
            List {
                SearchSection
                if !FilteredRunners.isEmpty {
                    InstalledSourcesSection
                }
                AnilistSection
            }
            .navigationTitle("Browse")
        }
        .navigationViewStyle(.stack)
    }

    var SearchSection: some View {
        Section {
            NavigationLink("Search All Sources") {
                SearchView()
            }
            NavigationLink("Image Search") {
                ImageSearchView()
            }
        } header: {
            Text("Search")
        }
    }
    
    var FilteredRunners: Results<StoredRunnerObject> {
        runners
            .sorted(by: [SortDescriptor(keyPath: "enabled", ascending: true),
                         SortDescriptor(keyPath: "name", ascending: true)])
    }

    @ViewBuilder
    var InstalledSourcesSection: some View {
        Section {
            ForEach(FilteredRunners) { runner in
                let source = manager.getSource(id: runner.id)
                if let source {
                    NavigationLink {
                        ExploreView(model: .init(source: source))
                    } label: {
                        HStack(spacing: 15) {
                            KFImage(URL(string: runner.thumbnail))
                                .placeholder { _ in
                                    Image("stt_icon")
                                        .resizable()
                                        .scaledToFill()
                                }
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32.0, height: 32.0)
                                .cornerRadius(5)
                            Text(source.name)
                            Spacer()
                        }
                    }
                    .disabled(!runner.enabled)
                }
            }
        } header: {
            Text("Content Sources")
        }
    }

    var AnilistSection: some View {
        Section {
            NavigationLink(destination: AnilistView.DirectoryView(model: .init(.defaultMangaRequest))) {
                MSLabelView(title: "Browse Manga", imageName: "anilist")
            }
            NavigationLink(destination: AnilistView.DirectoryView(model: .init(.defaultAnimeRequest))) {
                MSLabelView(title: "Browse Anime", imageName: "anilist")
            }
        } header: {
            Text("Anilist")
        }
    }
}
