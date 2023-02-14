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
    @EnvironmentObject var daisuke : DaisukeEngine
    @ObservedResults(StoredRunnerObject.self, sortDescriptor: .init(keyPath: "name")) var savedRunners
    @State var presentImporter = false
    var body: some View {
        NavigationView {
            List {
                SearchSection
                if !daisuke.getSources().isEmpty {
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
            NavigationLink("Search All") {
                SearchView()
            }
            NavigationLink("Image Search") {
                ImageSearchView()
            }
        } header: {
            Text("Search")
        }
    }

    @ViewBuilder
    var InstalledSourcesSection: some View {
        let sources = daisuke.getSources().sorted(by: { getSaved($0.id)?.order ?? 0 < getSaved($1.id)?.order ?? 0 })
        Section {
            ForEach(sources, id: \.id) { source in
                NavigationLink {
                    ExploreView()
                        .environmentObject(source)
                } label: {
                    let saved = getSaved(source.id)
                    HStack(spacing: 15) {
                        KFImage(saved?.thumbnail.flatMap({ URL(string: $0) }))
                            .placeholder({ _ in
                                Image("stt_icon")
                                    .resizable()
                                    .scaledToFill()
                            })
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32.0, height: 32.0)
                            .cornerRadius(5)
                        Text(source.name)
                        Spacer()
                    }
                }
            }
        } header: {
            Text("Content Sources")
        }
    }

    func getSaved(_ id: String) -> StoredRunnerObject? {
        savedRunners
            .where { $0.id == id }
            .first
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
