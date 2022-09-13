//
//  ProfileView+TrackersSheet.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-05-04.
//

import Kingfisher
import RealmSwift
import SwiftUI

extension ProfileView.Sheets {
    struct TrackersSheet: View {
        @EnvironmentObject var model: ProfileView.ViewModel
        @ObservedResults(TrackerLink.self) var trackerLinks
        var body: some View {
            NavigationView {
                List {
                    // Anilist
                    Section {
                        // ID is Linked
                        if let strId = model.content.trackerInfo?["al"] ?? linkedTracker?.trackerInfo?.al, let id = Int(strId) {
                            AnilistView.TrackerExcerptView(id: id)
                        } else {
                            NavigationLink(destination: AnilistView.LinkerView(entry: model.content, sourceId: model.source.id)) {
                                MSLabelView(title: "Link Content", imageName: "anilist")
                            }
                        }
                    } header: {
                        if let linkedTracker = linkedTracker {
                            HStack {
                                Spacer()
                                Button("Unlink") {
                                    withAnimation {
                                        DataManager.shared.unlinkContentToTracker(linkedTracker)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Trackers")
                .navigationBarTitleDisplayMode(.inline)
                .closeButton()
            }
        }

        var linkedTracker: TrackerLink? {
            trackerLinks.first(where: { model.sttIdentifier().id == $0._id })
        }
    }
}

extension AnilistView {
    struct TrackerExcerptTile: View {
        var data: Anilist.Media
        var body: some View {
            HStack {
                ZStack(alignment: .topLeading) {
                    BaseImageView(url: URL(string: data.coverImage.large))
                        .frame(width: 100, height: 150, alignment: .center)
                        .cornerRadius(7)
                        .shadow(radius: 2.5)

                    Image("anilist")
                        .resizable()
                        .frame(width: 27, height: 27, alignment: .center)
                        .cornerRadius(7)
                        .padding(.all, 3)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(data.title.userPreferred)
                        .font(.headline.weight(.semibold))
                    if let entry = data.mediaListEntry {
                        HStack {
                            Image(systemName: entry.status.systemImage)
                            Text(entry.status.description(for: data.type))
                        }
                        .foregroundColor(entry.status.color)
                        .font(.subheadline)

                        Text(" \(entry.progress) / \(data.chapters?.description ?? "-") Chapters")
                            .font(.subheadline)
                    } else {
                        Text("Not Tracking")
                            .font(.subheadline.weight(.light))
                    }

                    Spacer()
                }
                Spacer()
            }
            .padding(.vertical, 3)
        }
    }

    struct TrackerExcerptView: View {
        @State var loadable = Loadable<Anilist.Media>.idle
        var id: Int
        @State var markedForRefresh: Bool = false
        var body: some View {
            LoadableView(load, loadable) { data in
                NavigationLink(destination: AnilistView.ProfileView(entry: data.toSearchResult(), onStatusUpdated: { _, _ in })) {
                    TrackerExcerptTile(data: data)
                }
                .onDisappear {
                    markedForRefresh.toggle()
                }
                .onAppear {
                    if markedForRefresh {
                        loadable = .idle
                    }
                }
                .animation(.default, value: loadable)
            }
        }

        func load() {
            loadable = .loading
            Task { @MainActor in

                do {
                    let response = try await Anilist.shared.getProfile(id)
                    loadable = .loaded(response)
                } catch {
                    loadable = .failed(error)
                }
            }
        }
    }
}

extension Anilist.Media {
    func toSearchResult() -> Anilist.SearchResult {
        .init(id: id, type: type, status: status, isAdult: isAdult, title: .init(userPreferred: title.userPreferred), coverImage: .init(large: coverImage.large, extraLarge: coverImage.extraLarge, color: coverImage.color))
    }
}
