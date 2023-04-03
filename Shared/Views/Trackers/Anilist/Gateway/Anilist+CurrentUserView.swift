//
//  Anilist+CurrentUserView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-22.
//

import Kingfisher
import NukeUI
import SwiftUI

extension AnilistView {
    struct LoadableUserView: View {
        @State var loadable = Loadable<Anilist.User>.idle
        var body: some View {
            LoadableView(load, loadable) {
                CurrentUserView(account: $0)
            }
            .animation(.default, value: loadable)
        }

        func load() {
            loadable = .loading
            Task {
                do {
                    let data = try await Anilist.shared.getUser()
                    loadable = .loaded(data)
                } catch {
                    loadable = .failed(error)
                    Logger.shared.error("[Anilist] [UserView] \(error.localizedDescription)")
                }
            }
        }
    }
}

extension AnilistView {
    @MainActor
    struct CurrentUserView: View {
        @State var account: Anilist.User
        @State var profileColor = Color.anilistBlue
        @State var showMore = false
        @Environment(\.presentationMode) var presentationMode

        var body: some View {
            ScrollView {
                VStack {
                    Header
                    About
                        .padding(.horizontal)
                    LazyVStack(alignment: .leading, spacing: 7) {
                        // Info Stacks
                        MangaStats
                            .padding(.bottom)
                        AnimeStats

                        // Genre Breakdown
                        // Tag Breakdown
                    }
                    .padding(.horizontal)
                    .foregroundColor(profileColor.isDark ? .white : .black)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.profileColor, profileColor)
            .animation(.default, value: profileColor)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Sign Out", role: .destructive) {
                            Anilist.shared.deleteToken()
                            presentationMode.wrappedValue.dismiss()
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
            .tint(profileColor)
            .accentColor(profileColor)
        }

        var Header: some View {
            ZStack {
                // BG
                if let banner = account.bannerImage {
                    LazyImage(url: URL(string: banner))
                }

                // Gradient
                LinearGradient(colors: [.clear, Color(uiColor: UIColor.systemBackground)], startPoint: .top, endPoint: .bottom)
                VStack {
                    LazyImage(url: URL(string: account.avatar.large ?? "")) { state in
                        if let image = state.image {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .task {
                                    let color = state.imageContainer?.image.averageColor
                                    if let color {
                                        profileColor = Color(color)
                                    }
                                }
                                .transition(.opacity)
                        }
                        
                    }
                        .frame(width: 100, height: 100, alignment: .center)
                        .clipShape(Circle())
                        .shadow(radius: 3)
                        .overlay(Circle().stroke(Color.accentColor, lineWidth: 1))
                        .shadow(radius: 5)
                        .overlay(Circle().stroke(profileColor, lineWidth: 2))
                        .shadow(color: profileColor, radius: 7)
                        .padding(.vertical, 7)
                    Text(account.name)
                        .font(.title)
                        .fontWeight(.bold)
                }
            }

            .frame(width: UIScreen.main.bounds.width, height: 180, alignment: .center)
        }

        @ViewBuilder
        var About: some View {
            if let bio = account.about {
                MarkDownView(text: bio)
                    .font(.subheadline)
                    .foregroundColor(Color.primary.opacity(0.75))
                    .lineLimit(self.showMore ? nil : 3)
                    .onTapGesture {
                        withAnimation { self.showMore.toggle() }
                    }
            }
        }

        var MangaStats: some View {
            Group {
                VStack(alignment: .leading) {
                    Text("Manga")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    HStack {
                        InfoCell(header: "Manga Tracked", text: account.statistics.manga.count.description)
                    }
                    HStack {
                        InfoCell(header: "Volumes Read", text: account.statistics.manga.volumesRead.description)
                        InfoCell(header: "Chapters Read", text: account.statistics.manga.chaptersRead.description)
                    }
                    HStack {
                        InfoCell(header: "Mean Score", text: account.statistics.manga.meanScore.clean)
                        InfoCell(header: "Standard Deviation", text: account.statistics.manga.standardDeviation.description)
                    }

                    ScoreBreakdown(scores: account.statistics.manga.scorePreview)
                }
            }
        }

        var AnimeStats: some View {
            Group {
                VStack(alignment: .leading) {
                    Text("Anime")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    InfoCell(header: "Anime Tracked", text: account.statistics.anime.count.description)
                    HStack {
                        InfoCell(header: "Episodes Watched", text: account.statistics.anime.episodesWatched.description)
                        InfoCell(header: "Hours Watched", text: ((account.statistics.anime.minutesWatched) / 60).description)
                    }

                    HStack {
                        InfoCell(header: "Mean Score", text: account.statistics.anime.meanScore.description)
                        InfoCell(header: "Standard Deviation", text: account.statistics.anime.standardDeviation.clean)
                    }
                }
            }
        }
    }
}

extension AnilistView.CurrentUserView {
    struct InfoCell: View {
        var header: String
        var text: String
        var body: some View {
            HStack {
                VStack(alignment: .leading) {
                    Text(header)
                        .font(.callout)
                        .fontWeight(.light)
                    Text(text)
                        .fontWeight(.semibold)
                }
                Spacer()
            }
            .modifier(InfoCellModifier())
        }
    }

    struct InfoCellModifier: ViewModifier {
        @Environment(\.profileColor) var color

        func body(content: Content) -> some View {
            content
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                .padding(.horizontal, 10)
                .background(color.opacity(0.65))
                .cornerRadius(10)
        }
    }
}

extension AnilistView.CurrentUserView {
    struct ScoreBreakdown: View {
        var scores: [Anilist.Score]
        var body: some View {
            VStack(alignment: .leading) {
                Text("Score Breakdown")
                    .font(.callout)

                BarChart(bars: bars)
            }
            .modifier(InfoCellModifier())
        }

        var bars: [Bar] {
            let bars = Array(1 ... 10).map { val -> Bar in
                let score = scores.first(where: { $0.score == val })
                let bar = Bar(value: score?.count ?? 0, label: val.description)
                return bar
            }
            return bars
        }
    }
}

//  MARK: Color

private struct ProfileColor: EnvironmentKey {
    static let defaultValue = Color.anilistBlue
}

extension EnvironmentValues {
    var profileColor: Color {
        get { self[ProfileColor.self] }
        set { self[ProfileColor.self] = newValue }
    }
}
