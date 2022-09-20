//
//  AnilistView+ProfileView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-24.
//

import Kingfisher
import PartialSheet
import RealmSwift
import SwiftUI

extension AnilistView {
    struct ProfileView: View {
        var entry: Anilist.SearchResult

        var onStatusUpdated: (_ id: Int, _ status: Anilist.MediaListStatus) -> Void
        @State var loadable = Loadable<Anilist.Media>.idle
        @State var scoreFormat: Anilist.MediaListOptions.ScoreFormat?
        @ObservedObject var toastManager = ToastManager()
        @ObservedObject var anilistModel = Anilist.shared
        var body: some View {
            LoadableView(load, loadable) { data in
                DataView(data: data, onStatusUpdated: onStatusUpdated, scoreFormat: scoreFormat)
            }
            .navigationTitle(entry.title.userPreferred)
            .navigationBarTitleDisplayMode(.inline)
            .toast(isPresenting: $toastManager.show) {
                toastManager.toast
            }
            .environmentObject(toastManager)
            .onChange(of: anilistModel.notifier) { _ in
                load()
            }
        }

        func load() {
            loadable = .loading
            Task { @MainActor in

                do {
                    let data = try await Anilist.shared.getProfile(entry.id)
                    loadable = .loaded(data)
                    scoreFormat = (try? await Anilist.shared.getUser())?.mediaListOptions.scoreFormat
                } catch {
                    loadable = .failed(error)
                }
            }
        }
    }
}

extension AnilistView.ProfileView {
    struct DataView: View {
        @State var data: Anilist.Media
        @State var lineLimit: Int? = 3
        @State var presentTrackingOptions = false
        @State var presentTrackerEdit = false
        @State var presentAuthSheet = false
        var onStatusUpdated: (_ id: Int, _ status: Anilist.MediaListStatus) -> Void
        @State var mediaList: Anilist.Media.MediaListEntry? = nil
        var scoreFormat: Anilist.MediaListOptions.ScoreFormat?
        @EnvironmentObject var toastManager: ToastManager
        var body: some View {
            ScrollView {
                VStack {
                    // Header
                    HeaderView

                    // Media List Entry
                    MediaListView

                    // Genres
                    GenresView

                    // Tags
                    TagsView
                }
            }
            .animation(.default, value: lineLimit)
            .animation(.default, value: data.isFavourite)
            .animation(.default, value: data.mediaListEntry)
            .fullScreenCover(isPresented: $presentAuthSheet) {
                NavigationView {
                    AnilistView.Gateway()
                        .closeButton()
                }
            }
            .onAppear(perform: {
                mediaList = data.mediaListEntry
            })
            .fullScreenCover(isPresented: $presentTrackerEdit) {
                if let entry = mediaList, let format = scoreFormat {
                    NavigationView {
                        AnilistView.EntryEditor(entry: entry, media: data, scoreFormat: format, onListUpdated: { list in
                            data.mediaListEntry = list
                            mediaList = list
                        })
                        .navigationTitle(data.title.userPreferred)
                        .navigationBarTitleDisplayMode(.inline)
                        .attachPartialSheetToRoot()
                        .closeButton()
                    }
                } else {
                    Text("-")
                }
            }
            .confirmationDialog("Tracking", isPresented: $presentTrackingOptions) {
                ForEach(Anilist.MediaListStatus.allCases, id: \.rawValue) { option in
                    Button(option.description(for: data.type)) {
                        Task { @MainActor in
                            await updateStatus(option: option)
                        }
                    }
                }
            }

            .tint(EntryColor)
        }
    }
}

extension AnilistView.ProfileView.DataView {
    var HeaderView: some View {
        VStack(alignment: .leading) {
            ZStack(alignment: .leading) {
                BaseImageView(url: URL(string: data.bannerImage ?? ""))
                    .blur(radius: 2.5)
                    .frame( height: 220, alignment: .center)
                    .clipped()

                LinearGradient(colors: [.clear, Color(uiColor: UIColor.systemBackground)], startPoint: .top, endPoint: .bottom)
                    .offset(x: 0, y: 3)
                    .padding(.bottom, 3)

                HStack {
                    BaseImageView(url: URL(string: data.coverImage.large))
                        .frame(width: 120, height: 180, alignment: .center)
                        .cornerRadius(7)
                        .padding(.vertical)
                        .shadow(radius: 2.5)
                        .padding(.horizontal)
                }
            }
            .frame(height: 220, alignment: .center)
            VStack(alignment: .leading) {
                Text(data.title.userPreferred)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let summary = data.description {
                    MarkDownView(text: summary)
                        .lineLimit(lineLimit)
                        .onTapGesture {
                            if lineLimit != nil {
                                lineLimit = nil
                            } else {
                                lineLimit = 3
                            }
                        }
                }
            }
            .padding(.horizontal)

            Divider()
        }
    }
}

private typealias PView = AnilistView.ProfileView.DataView

// MARK: Tags & Genres

extension PView {
    var GenresView: some View {
        HStack {
            InteractiveTagView(data.genres) { genre in
                InteractiveTagCell(genre) {
                    AnilistView.DirectoryView(model: .init(.init(type: data.type, genres: [genre])))
                }
            }
        }
        .padding(.horizontal)
    }

    var TagsView: some View {
        VStack(spacing: 10) {
            ForEach(Array(Dictionary(grouping: data.tags, by: { $0.category }).keys).sorted(by: { $0 < $1 })) { category in
                let tags = data.tags.filter { $0.category == category }
                VStack(alignment: .leading, spacing: 7) {
                    Text(category)
                        .font(.callout)
                        .fontWeight(.semibold)
                    InteractiveTagView(tags.sorted(by: { $0.name < $1.name })) { tag in
                        InteractiveTagCell(tag.name) {
                            AnilistView.DirectoryView(model: .init(.init(type: data.type, tags: [tag.name])))
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: Entry

extension PView {
    var EntryColor: Color {
        if let color = data.coverImage.color {
            return Color(hex: color)
        }

        return .anilistBlue
    }

    func updateStatus(option: Anilist.MediaListStatus) async {
        do {
            let updated = try await Anilist.shared.updateMediaListEntry(mediaId: data.id,
                                                                        data: ["status": option.rawValue])
            mediaList = updated
            onStatusUpdated(updated.id, updated.status)
            toastManager.setComplete(title: "Synced.")

        } catch {
            toastManager.setError(error: error)
        }
    }

    var MediaListView: some View {
        HStack {
            Button { !Anilist.signedIn() ? presentAuthSheet.toggle() : presentTrackingOptions.toggle() } label: {
                Text(mediaList?.status.description(for: data.type) ?? "Track")
                    .font(.headline.weight(.semibold))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(EntryColor)
                    .cornerRadius(7)
                    .foregroundColor(EntryColor.isDark ? .white : .black)
            }

            if mediaList != nil {
                Button { presentTrackerEdit.toggle() } label: {
                    Image(systemName: "pencil")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding()
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                        .background(EntryColor)
                        .foregroundColor(EntryColor.isDark ? .white : .black)
                        .cornerRadius(7)
                }
                .transition(.slide)
            }

            Button { data.isFavourite.toggle() } label: {
                Image(systemName: "heart.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding()
                    .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                    .background(data.isFavourite ? Color.red : Color.sttGray)
                    .foregroundColor(data.isFavourite ? Color.white : Color.red)
                    .cornerRadius(7)
            }
            .disabled(data.isFavouriteBlocked)
        }
        .buttonStyle(.plain)
        .frame(height: 55)
        .padding(.horizontal)
    }
}

struct FieldLabel: View {
    var primary: String
    var secondary: String
    var body: some View {
        HStack {
            Text(primary)
            Spacer()
            Text(secondary)
                .fontWeight(.light)
                .foregroundColor(.primary.opacity(0.5))
        }
    }
}
