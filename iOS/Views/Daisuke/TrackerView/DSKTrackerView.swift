//
//  DSKTrackerView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-08-31.
//

import NukeUI
import SwiftUI

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = nil
    }
}

struct DSKLoadableTrackerView: View {
    let tracker: AnyContentTracker
    let item: DSKCommon.Highlight
    @State var loadable: Loadable<DSKCommon.FullTrackItem> = .idle

    var body: some View {
        LoadableView(load, $loadable) {
            DSKTrackerView(tracker: tracker, content: .placeholder)
                .redacted(reason: .placeholder)
                .transition(.opacity)
        } content: { value in
            DSKTrackerView(tracker: tracker, content: value)
                .transition(.opacity)
        }
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
    }

    func load() async throws {
        let data = try await tracker.getFullInformation(id: item.id)
        withAnimation(.easeInOut(duration: 0.33)) {
            loadable = .loaded(data)
        }
    }
}

struct DSKTrackerView: View {
    let tracker: AnyContentTracker
    let content: DSKCommon.FullTrackItem
    @Environment(\.presentationMode) private var presentationMode
    @State private var lineLimit: Int? = 3
    @State private var status: DSKCommon.TrackStatus?
    @State private var isFavorite: Bool?
    @AppStorage(STTKeys.TileStyle) private var style = TileStyle.SEPARATED

    @State private var presentStatusDialog = false
    @State private var presentSearchView = false
    @State private var presentEntryForm = false
    @State private var initialLoad = false
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                VStack(spacing: 5) {
                    StickyHeader
                    HeaderView
                }
                VStack(spacing: 15) {
                    TrackerEntryView
                    LinksView
                    PropertiesView
                    CollectionsView
                    CharactersView
                }
                .padding(.bottom)
            }
        }
        .coordinateSpace(name: "scroll")
        .ignoresSafeArea(edges: .top)
        .animation(.default, value: lineLimit)
        .modifier(TrackStatusModifier(title: nil,
                                      tracker: tracker,
                                      contentID: content.id,
                                      alreadyTracking: Binding.constant(status != nil),
                                      isPresenting: $presentStatusDialog,
                                      callback: { s in
                                          withAnimation {
                                              status = s
                                          }

                                      }))
        .fullScreenCover(isPresented: $presentEntryForm) {
            SmartNavigationView {
                DSKLoadableForm(runner: tracker, context: .tracker(id: content.id))
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle(content.title)
                    .closeButton()
            }
        }
        .task {
            load()
        }
    }
}

// MARK: Header

extension DSKTrackerView {
    private var info: [String] {
        var titles = [String]()
        if content.isNSFW ?? false {
            titles.append("NSFW")
        }

        let status = (content.status ?? ContentStatus.UNKNOWN).description
        titles.append(status)

        titles.append(contentsOf: content.info ?? [])

        return titles
    }

    private var bannerURL: URL? {
        (content.bannerCover ?? content.cover).flatMap { URL(string: $0) }
    }

    @MainActor
    private var StickyHeader: some View {
        GeometryReader { proxy in
            let frame = proxy.frame(in: .named("scroll"))
            let minY = frame.minY
            let size = proxy.size
            let height = max(size.height + minY, size.height)

            LazyImage(url: bannerURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .blur(radius: 2.5)
                        .offset(x: 0, y: -4)
                }
            }
            .frame(width: size.width, height: height, alignment: .top)
            .clipped()
            .overlay {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [.clear, Color(uiColor: UIColor.systemBackground)], startPoint: .top, endPoint: .bottom)
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .bottom) {
                            Button("\(Image(systemName: "chevron.left"))") {
                                presentationMode.wrappedValue.dismiss()
                            }
                            .font(.title3)
                            .foregroundColor(.white)
                            .unredacted()
                            Spacer()
                            HStack(spacing: 20) {
                                NavigationLink("\(Image(systemName: "magnifyingglass"))") {
                                    SearchView(initialQuery: content.title)
                                }
                                .font(.title3)

                                if let url = URL(string: content.webUrl) {
                                    Link(destination: url) {
                                        Text("\(Image(systemName: "square.and.arrow.up"))")
                                            .font(.title3)
                                    }
                                }
                            }
                            .foregroundColor(.white)
                        }
                        .frame(height: getKeyWindow()?.safeAreaInsets.top ?? 0)

                        Spacer()
                        HStack(alignment: .bottom) {
                            BaseImageView(url: URL(string: content.cover))
                                .frame(width: 120, height: 180, alignment: .center)
                                .cornerRadius(7)
                                .shadow(radius: 2.5)
                            InteractiveTagView(info) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                    .background((tag == "NSFW" ? Color.red : Color.random).opacity(0.65))
                                    .cornerRadius(3)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, getKeyWindow()?.safeAreaInsets.top ?? 0)
                    .padding(.bottom, 25)
                }
            }
            .offset(y: minY > 0 ? -minY : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300, alignment: .center)
    }

    private var HeaderView: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text(content.title)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let summary = content.summary?.trimmingCharacters(in: .whitespacesAndNewlines) {
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

// MARK: TrackerEntryView

extension DSKTrackerView {
    private var trackEntry: DSKCommon.TrackEntry? {
        content.entry
    }

    private var entryColor: Color {
        status?.color ?? .accentColor
    }

    private var TrackerEntryView: some View {
        HStack {
            Button {
                presentStatusDialog.toggle()
            } label: {
                Text(status?.description ?? "Track")
                    .font(.headline.weight(.semibold))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(entryColor)
                    .foregroundColor(entryColor.isDark ? .white : .black)
                    .cornerRadius(7)
            }

            if status != nil {
                Button { presentEntryForm.toggle() } label: {
                    Image(systemName: "pencil")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding()
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                        .background(entryColor)
                        .foregroundColor(entryColor.isDark ? .white : .black)
                        .cornerRadius(7)
                }
                .transition(.slide)
            }

            if let favorite = isFavorite {
                Button {} label: {
                    Image(systemName: favorite ? "heart.fill" : "heart")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding()
                        .clipShape(RoundedRectangle(cornerSize: CGSize(width: 20, height: 20)))
                        .background(favorite ? Color.red : Color.secondary.opacity(0.25))
                        .foregroundColor(favorite ? Color.white : Color.red)
                        .cornerRadius(7)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(height: 55)
        .padding(.horizontal)
    }
}

extension DSKTrackerView {
    private func load() {
        guard !initialLoad else { return }
        initialLoad = true
        isFavorite = content.isFavorite
        status = trackEntry?.status
    }
}

// MARK: Properties

extension DSKTrackerView {
    @ViewBuilder
    private var PropertiesView: some View {
        Group {
            if let properties = content.properties {
                ForEach(properties) { property in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(property.title)
                            .font(.subheadline)
                            .fontWeight(.bold)

                        InteractiveTagView(property.tags) { tag in
                            InteractiveTagCell(tag.title) {
                                ContentTrackerDirectoryView(tracker: tracker,
                                                            request: .init(page: 1,
                                                                           tag: .init(tagId: tag.id,
                                                                                      propertyId: property.id)))
                                    .navigationTitle(tag.title + " Titles")
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: Links View

extension DSKTrackerView {
    private var LinksView: some View {
        Group {
            if let links = content.links {
                InteractiveTagView(links) { tag in
                    Link("\(Image(systemName: "link")) \(tag.title)",
                         destination: URL(string: tag.url) ?? STTHost.notFound)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .font(.caption)
                }
            }
        }
        .padding(.horizontal)
    }
}

// MARK: Collections View

extension DSKTrackerView {
    private var CollectionsView: some View {
        VStack {
            if let collection = content.relatedTitles, !collection.isEmpty {
                CollectionView(tracker: tracker, title: "Related Titles", collection: collection)
            }

            if let collection = content.recommendedTitles, !collection.isEmpty {
                CollectionView(tracker: tracker, title: "Recommended Titles", collection: collection)
            }
        }
    }
}

extension DSKTrackerView {
    struct CollectionView: View {
        let tracker: AnyContentTracker
        let title: String
        let collection: [DSKCommon.Highlight]

        var body: some View {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline.weight(.semibold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(collection) {
                            Cell(tracker: tracker, data: $0)
                        }
                    }
                }
                .padding(.top, 5)
            }
            .padding(.horizontal)
        }
    }

    struct Cell: View {
        @AppStorage(STTKeys.TileStyle) private var style = TileStyle.SEPARATED
        @State var tracker: AnyContentTracker
        @State var data: DSKCommon.Highlight

        var body: some View {
            NavigationLink {
                DSKLoadableTrackerView(tracker: tracker, item: data)
            } label: {
                DefaultTile(entry: .init(id: data.id, cover: data.cover, title: data.title))
                    .coloredBadge(data.entry?.status.color)
                    .modifier(TrackerContextModifier(tracker: tracker, item: $data, status: data.entry?.status ?? .CURRENT))
                    .frame(width: 150, height: CELL_HEIGHT)
            }
            .buttonStyle(NeutralButtonStyle())
        }

        var CELL_HEIGHT: CGFloat {
            let base: CGFloat = 150
            var height = 1.5 * base

            if style == .SEPARATED {
                height += 50
            }
            return height
        }
    }
}

extension DSKTrackerView {
    @ViewBuilder
    var CharactersView: some View {
        if let characters = content.characters {
            VStack(alignment: .leading) {
                Text("Characters")
                    .font(.headline.weight(.semibold))
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack {
                        ForEach(characters, id: \.hashValue) { character in
                            DefaultTile(entry: .init(id: content.id, cover: character.image ?? "", title: character.name))
                                .frame(width: 150, height: CELL_HEIGHT)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .padding(.horizontal)
        }
    }

    var CELL_HEIGHT: CGFloat {
        let base: CGFloat = 150
        var height = 1.5 * base

        if style == .SEPARATED {
            height += 50
        }
        return height
    }
}

struct TrackStatusModifier: ViewModifier {
    let title: String?
    let tracker: AnyContentTracker
    let contentID: String
    @Binding var alreadyTracking: Bool
    @Binding var isPresenting: Bool
    let callback: ((DSKCommon.TrackStatus) -> Void)?
    func body(content: Content) -> some View {
        content
            .confirmationDialog(title ?? "Status", isPresented: $isPresenting) {
                ForEach(DSKCommon.TrackStatus.allCases, id: \.rawValue) { option in
                    Button(option.description) {
                        update(with: option)
                    }
                }
            }
    }

    private func update(with status: DSKCommon.TrackStatus) {
        Task {
            do {
                if alreadyTracking {
                    try await tracker.didUpdateStatus(id: contentID, status: status)
                } else {
                    try await tracker.beginTracking(id: contentID, status: status)
                }
                callback?(status)
            } catch {
                Logger.shared.error(error)
                ToastManager.shared.error(error)
            }
        }
    }
}
