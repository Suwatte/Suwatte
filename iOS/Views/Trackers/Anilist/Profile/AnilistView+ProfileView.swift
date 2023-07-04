//
//  AnilistView+ProfileView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2022-04-24.
//
import NukeUI
import PartialSheet
import RealmSwift
import SwiftUI

extension AnilistView {
    struct ProfileView: View {
        struct BasicEntry {
            var id: Int
            var title: String
            var webUrl: URL?
        }

        var entry: BasicEntry

        var onStatusUpdated: (_ id: Int, _ status: Anilist.MediaListStatus) -> Void
        @State var loadable = Loadable<Anilist.Media>.idle
        @State var scoreFormat: Anilist.MediaListOptions.ScoreFormat?
        @ObservedObject var anilistModel = Anilist.shared

        var body: some View {
            LoadableView(load, loadable) { data in
                DataView(data: data, onStatusUpdated: onStatusUpdated, scoreFormat: scoreFormat)
                    .transition(.opacity)
            }
            .toast()
            .onChange(of: anilistModel.notifier) { _ in
                load()
            }
            .navigationBarHidden(true)
            .animation(.default, value: loadable)
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
        @Environment(\.presentationMode) var presentationMode
        @State var presentGlobalSearch = false

        var body: some View {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 5) {
                    StickyHeader
                    HeaderView
                }
                VStack(spacing: 20) {
                    MediaListView

                    // Genres
                    GenresView

                    // Tags
                    TagsView
                }
                .padding(.bottom)
            }
            .coordinateSpace(name: "scroll")
            .ignoresSafeArea(edges: .top)
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

            .tint(Color.primary)
            .hiddenNav(presenting: $presentGlobalSearch) {
                SearchView(initialQuery: data.title.userPreferred)
            }
        }
    }
}

extension AnilistView.ProfileView.DataView {
    var StickyHeader: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("scroll"))
            let minY = frame.minY
            let size = proxy.size
            let height = max(size.height + minY, size.height)
            LazyImage(url: data.bannerImage.flatMap { URL(string: $0) } ?? URL(string: data.coverImage.extraLarge)) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 2.5)
                        .offset(x: 0, y: -4)
                }
            }
            .frame(width: size.width, height: height, alignment: .top)
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, Color(uiColor: UIColor.systemBackground)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .bottom) {
                            Button("\(Image(systemName: "chevron.left"))") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .font(.title3)
                            Spacer()
                            Menu("\(Image(systemName: "ellipsis"))") {
                                Button {
//                                    presentGlobalSearch.toggle()
                                } label: {
                                    Label("Find on Source", systemImage: "magnifyingglass")
                                }

                                Link(destination: data.webUrl ?? STTHost.notFound) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                        }
                        .frame(height: KEY_WINDOW?.safeAreaInsets.top ?? 0)

                        Spacer()
                        BaseImageView(url: URL(string: data.coverImage.large))
                            .frame(width: 120, height: 180, alignment: .center)
                            .cornerRadius(7)
                            .shadow(radius: 2.5)
                    }
                    .padding(.horizontal)
                    .padding(.top, KEY_WINDOW?.safeAreaInsets.top ?? 0)
                    .padding(.bottom, 25)
                }
            }
            .offset(y: minY > 0 ? -minY : 0)
        }
        .frame(width: UIScreen.main.bounds.width, height: 300, alignment: .center)
    }

    var HeaderView: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text(data.title.userPreferred)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let summary = data.description {
                    HTMLStringView(text: summary)
                        .font(.body.weight(.light))
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
            Divider()
        }
        .padding(.horizontal)
    }
}

private typealias PView = AnilistView.ProfileView.DataView

// MARK: Tags & Genres

extension PView {
    var GenresView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Genres")
                .font(.subheadline)
                .fontWeight(.bold)
            HStack {
                InteractiveTagView(data.genres) { genre in
                    InteractiveTagCell(genre) {
                        AnilistView.DirectoryView(model: .init(.init(type: data.type, genres: [genre])))
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    var TagsView: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Tags")
                .font(.subheadline)
                .fontWeight(.bold)
            InteractiveTagView(tags) { tag in
                InteractiveTagCell(tag.name) {
                    AnilistView.DirectoryView(model: .init(.init(type: data.type, tags: [tag.name])))
                }
            }
        }
        .padding(.horizontal)
    }

    var tags: [Anilist.Media.MediaTag] {
        let base = data.tags.filter { $0.category != "Sexual Content" }.sorted(by: { $0.name < $1.name })

        if base.count <= 8 {
            return base
        }
        return Array(base[0 ... 8])
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
            ToastManager.shared.display(.info("Synced!"))
        } catch {
            ToastManager.shared.display(.error(error))
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
                    .background(data.isFavourite ? Color.red : Color.secondary.opacity(0.25))
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

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = nil
    }
}