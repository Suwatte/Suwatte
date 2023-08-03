//
//  PageView+CollectionView.swift
//  Suwatte (iOS)
//
//  Created by Mantton on 2023-07-12.
//

import ASCollectionView
import SwiftUI

extension DSKPageView {
    struct CollectionView: View {
        let pageSections: [DSKCommon.PageSection<T>]
        let runner: JSCRunner
        let tileModifier: PageItemModifier
        @State var locked = false
        @AppStorage(STTKeys.TileStyle) var tileStyle = TileStyle.SEPARATED
        @AppStorage(STTKeys.GridItemsPerRow_P) var PortraitPerRow = 2
        @AppStorage(STTKeys.GridItemsPerRow_LS) var LSPerRow = 6
        @EnvironmentObject var model: ViewModel

        init(sections: [DSKCommon.PageSection<T>], runner: JSCRunner, @ViewBuilder _ tileModifier: @escaping PageItemModifier) {
            pageSections = sections
            self.runner = runner
            self.tileModifier = tileModifier
        }

        var body: some View {
            ASCollectionView(sections: self.sections)
                .layout(self.layout)
                .onPullToRefresh { endRefreshing in
                    model.loadable = .idle
                    endRefreshing()
                }
                .shouldInvalidateLayoutOnStateChange(true)
                .alwaysBounceVertical()
                .animateOnDataRefresh(true)
                .ignoresSafeArea(.keyboard, edges: .all)
                .task { loadAll() }
                .onChange(of: tileStyle) { _ in } // Triggers view Update when key is updated
                .onChange(of: PortraitPerRow, perform: { _ in })
                .onChange(of: LSPerRow, perform: { _ in })
                .onChange(of: model.errors, perform: { _ in })
                .onChange(of: model.loadables, perform: { _ in })
        }
    }
}

// MARK: - Load Methods

extension DSKPageView.CollectionView {
    func loadAll(force: Bool = false) {
        guard !locked && !force else { return }
        locked = true // prevent from refiring
        let unresolved = pageSections.filter { $0.items == nil }.map(\.key)

        Task {
            await withTaskGroup(of: Void.self, body: { group in
                for section in unresolved {
                    group.addTask {
                        await model.load(section)
                    }
                }
            })
        }
    }
}

// MARK: - Layout

extension DSKPageView.CollectionView {
    var layout: ASCollectionLayout<String> {
        let cache = Dictionary(uniqueKeysWithValues: pageSections.map { ($0.key, $0.sectionStyle) })
        return ASCollectionLayout { sectionID in
            let errors = model.errors
            // Errored Out, Show Error Layout
            if errors.contains(sectionID) {
                return .init {
                    ErrorLayout()
                }
            }
            // Either Loading or has loaded will show redacted placeholders to match
            switch cache[sectionID]! {
            case .GALLERY:
                return .init { environment in
                    GalleryLayout(environment)
                }
            case .INFO:
                return .init { environment in
                    InfoLayout(environment)
                }
            case .DEFAULT:
                return .init {
                    NormalLayout()
                }
            case .PADDED_LIST:
                return .init { environment in
                    LastestLayout(environment)
                }
            case .STANDARD_GRID:
                return .init { environment in
                    GridLayout(environment)
                }
            case .NAVIGATION_LIST:
                return .init { environment in
                    InsetListLayout(environment)
                }
            case .ITEM_LIST:
                return .init { environment in
                    InsetListLayout(environment)
                }
            case .TAG:
                return .init {
                    TagsLayout()
                }
            }
        }
    }
}

// MARK: - Sections

extension DSKPageView.CollectionView {
    var sections: [ASCollectionViewSection<String>] {
        let loadables = model.loadables
        return pageSections.map { section -> ASCollectionViewSection<String> in
            let key = section.key
            // Section was preloaded
            if let data = section.items {
                return LoadedSection(section, data)
            }

            // Collection not loaded, find loadable and display based off state
            let loadable = loadables[key] ?? .loading

            switch loadable {
            case let .failed(error): return ErrorSection(section, error: error)
            case .loading, .idle: return LoadingSection(section)
            case let .loaded(data): return LoadedSection(section, data.items, data)
            }
        }
    }
}

extension DSKPageView.CollectionView {
    func buildHeader(_ title: String, _ subtitle: String?, _ linkable: DSKCommon.Linkable?) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .fontWeight(.light)
                        .lineLimit(2)
                        .opacity(0.75)
                }
            }
            Spacer()
            if let linkable {
                NavigationLink("View More \(Image(systemName: "chevron.right"))") {
                    buildLinkableView(linkable)
                        .navigationBarTitle(title)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(.accentColor)
                .font(.caption)
            }
        }
    }
}

// MARK: - Section Builders

extension DSKPageView.CollectionView {
    func PageNotFoundSection(_ section: DSKCommon.PageSection<T>) -> ASCollectionViewSection<String> {
        ASCollectionViewSection(id: section.key) {
            Text("Section not found.")
        }
        .sectionHeader {
            buildHeader(section.title,
                        section.subtitle,
                        section.viewMoreLink)
        }
        .sectionFooter {
            EmptyView()
        }
    }

    func ErrorSection(_ section: DSKCommon.PageSection<T>, error: Error) -> ASCollectionViewSection<String> {
        ASCollectionViewSection(id: section.key) {
            ErrorView(error: error, runnerID: runner.id) {
                Task.detached {
                    if case DaisukeEngine.Errors.Cloudflare = error {
                        await loadAll(force: true)
                    } else {
                        await model.load(section.key)
                    }
                }
            }
        }
        .sectionHeader {
            buildHeader(section.title,
                        section.subtitle,
                        section.viewMoreLink)
        }
        .sectionFooter {
            EmptyView()
        }
    }

    func LoadedSection(_ section: DSKCommon.PageSection<T>, _ items: [DSKCommon.PageItem<T>], _ resolved: DSKCommon.ResolvedPageSection<T>? = nil) -> ASCollectionViewSection<String> {
        ASCollectionViewSection(id: section.key, data: items, dataID: \.hashValue) { data, _ in
            buildPageItemView(data)
                .environment(\.pageSectionStyle, section.sectionStyle)
        }
        .sectionHeader {
            buildHeader(resolved?.updatedTitle ?? section.title,
                        resolved?.updatedSubtitle ?? section.subtitle,
                        resolved?.viewMoreLink ?? section.viewMoreLink)
        }
        .sectionFooter {
            EmptyView()
        }
    }

    func LoadingSection(_ section: DSKCommon.PageSection<T>) -> ASCollectionViewSection<String> {
        ASCollectionViewSection(id: section.key, data: DSKCommon.Highlight.placeholders()) { data, _ in
            PageViewTile(runnerID: runner.id,
                         id: data.id,
                         title: data.title,
                         subtitle: data.subtitle,
                         cover: data.cover,
                         additionalCovers: [],
                         info: data.info,
                         badge: data.badge)
                .environment(\.pageSectionStyle, section.sectionStyle)
                .redacted(reason: .placeholder)
                .shimmering()
        }
        .sectionHeader {
            buildHeader(section.title,
                        section.subtitle,
                        section.viewMoreLink)
        }
        .sectionFooter {
            EmptyView()
        }
    }
}

// MARK: - Define Secton Style Environment Key

private struct PageSectionStyleKey: EnvironmentKey {
    static let defaultValue = DSKCommon.SectionStyle.DEFAULT
}

extension EnvironmentValues {
    var pageSectionStyle: DSKCommon.SectionStyle {
        get { self[PageSectionStyleKey.self] }
        set { self[PageSectionStyleKey.self] = newValue }
    }
}

// MARK: - Builder

extension DSKPageView.CollectionView {
    func buildLinkableView(_ linkable: DSKCommon.Linkable) -> some View {
        Group {
            if linkable.isPageLink, let link = linkable.page {
                RunnerPageView(runner: runner, link: link)
            } else {
                RunnerDirectoryView(runner: runner, request: linkable.getDirectoryRequest())
            }
        }
    }

    func buildPageItemView(_ data: DSKCommon.PageItem<T>) -> some View {
        Group {
            if let link = data.link {
                NavigationLink {
                    PageLinkView(pageLink: link, runnerID: runner.id)
                } label: {
                    PageViewTile(runnerID: runner.id, id: link.hashValue.description, title: link.title, subtitle: link.subtitle, cover: link.cover ?? "", additionalCovers: nil, info: nil, badge: link.badge)
                }
                .buttonStyle(NeutralButtonStyle())
            } else if let item = data.item {
                tileModifier(item)
            }
        }
    }
}
