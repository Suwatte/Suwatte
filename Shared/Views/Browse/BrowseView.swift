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
    @EnvironmentObject var daisuke: DaisukeEngine
    @ObservedResults(StoredRunnerObject.self) var runners
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
            NavigationLink("Search All Content Sources") {
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
        let results = runners.sorted(by: [SortDescriptor(keyPath: "enabled", ascending: true), SortDescriptor(keyPath: "name", ascending: true)])
        Section {
            ForEach(results) { runner in
                let source = DSK.shared.getSource(with: runner.id)
                
                if let source {
                    NavigationLink {
                        ExploreView()
                            .environmentObject(source)
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
